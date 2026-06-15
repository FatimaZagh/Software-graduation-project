/// Local presentation-mode health assistant — dynamic token-aware replies (no network).
String generatePseudoMedicalResponse(
  String userInput, {
  Map<String, dynamic>? patientContext,
  bool medicationMode = false,
}) {
  final raw = userInput.trim();
  if (raw.isEmpty) {
    return _wrap(
      'Thank you for contacting Rafeeq Health Assistant.',
      'Please describe your symptoms, medication, or health concern so I can offer structured guidance.',
      'If anything feels urgent, contact your clinic or emergency services immediately.',
    );
  }

  final lower = raw.toLowerCase();
  final tokens = _tokenize(lower);
  final topic = _resolveTopic(raw, tokens, patientContext, medicationMode);

  if (_isGreeting(lower, tokens)) {
    return _wrap(
      'Hello — I am Rafeeq Health Assistant.',
      'Regarding your message, I am ready to discuss clinical topics such as symptoms, medications, follow-up care, and wellness planning.',
      'Share any concern in your own words and I will respond with structured, patient-friendly guidance.',
    );
  }

  final symptoms = _matchFrom(tokens, _symptomLexicon);
  final medications = _matchMedications(tokens, raw, patientContext, medicationMode);
  final conditions = _matchFrom(tokens, _conditionLexicon);
  final vitals = _matchFrom(tokens, _vitalLexicon);

  final clinicalFocus = <String>[
    if (medications.isNotEmpty) 'medication therapy (${medications.join(', ')})',
    if (symptoms.isNotEmpty) 'reported symptoms (${symptoms.join(', ')})',
    if (conditions.isNotEmpty) 'clinical context (${conditions.join(', ')})',
    if (vitals.isNotEmpty) 'physiologic indicators (${vitals.join(', ')})',
  ];

  final focusLine = clinicalFocus.isNotEmpty
      ? clinicalFocus.join('; ')
      : 'your query about "$topic"';

  final classification = _classify(clinicalFocus, medicationMode);
  final management = _managementPlan(clinicalFocus, medicationMode);
  final monitoring = _monitoringAdvice(clinicalFocus);

  return _wrap(
    'Regarding your query about $topic, this is clinically classified as $classification.',
    'From the terms identified ($focusLine), common management protocols include: $management',
    'Please monitor closely for worsening signs, medication side effects, or new symptoms, and $monitoring',
    'This guidance is educational only — confirm any treatment change with your licensed physician or pharmacist.',
  );
}

String _wrap(String opening, String body, String closing, [String? footer]) {
  final parts = [opening, body, closing];
  if (footer != null && footer.isNotEmpty) parts.add(footer);
  return parts.join('\n\n');
}

List<String> _tokenize(String lower) {
  return RegExp(r'[\w\u0600-\u06FF]+')
      .allMatches(lower)
      .map((m) => m.group(0)!)
      .where((w) => w.length > 1)
      .toList();
}

bool _isGreeting(String lower, List<String> tokens) {
  if (tokens.length <= 4 &&
      RegExp(r'^(hi|hello|hey|salam|marhaba|good\s(morning|evening|afternoon)|thanks|thank\syou)\b')
          .hasMatch(lower)) {
    return true;
  }
  return tokens.length <= 2 && {'hi', 'hello', 'hey', 'salam'}.contains(tokens.firstOrNull);
}

String _resolveTopic(
  String raw,
  List<String> tokens,
  Map<String, dynamic>? ctx,
  bool medicationMode,
) {
  if (medicationMode) {
    final focused = ctx?['focusedMedication']?.toString().trim();
    if (focused != null && focused.isNotEmpty) return focused;
  }
  if (tokens.length >= 3) {
    final slice = tokens.take(6).join(' ');
    return slice[0].toUpperCase() + slice.substring(1);
  }
  if (raw.length > 64) return '${raw.substring(0, 61)}...';
  return raw;
}

List<String> _matchFrom(List<String> tokens, Map<String, String> lexicon) {
  final hits = <String>[];
  for (final t in tokens) {
    final label = lexicon[t];
    if (label != null && !hits.contains(label)) hits.add(label);
  }
  for (final entry in lexicon.entries) {
    if (entry.key.contains(' ') && tokens.join(' ').contains(entry.key) && !hits.contains(entry.value)) {
      hits.add(entry.value);
    }
  }
  return hits;
}

List<String> _matchMedications(
  List<String> tokens,
  String raw,
  Map<String, dynamic>? ctx,
  bool medicationMode,
) {
  final hits = <String>[];
  void add(String? v) {
    final s = v?.trim();
    if (s != null && s.isNotEmpty && !hits.contains(s)) hits.add(s);
  }

  if (medicationMode) add(ctx?['focusedMedication']?.toString());

  final active = ctx?['activeMedications'];
  if (active is List) {
    for (final m in active) {
      add(m?.toString());
    }
  }

  hits.addAll(_matchFrom(tokens, _medicationLexicon));

  final capWords = RegExp(r'\b[A-Z][a-z]{2,}(?:\s+[A-Z][a-z]+)?\b').allMatches(raw);
  for (final m in capWords) {
    add(m.group(0));
  }

  return hits.take(4).toList();
}

String _classify(List<String> clinicalFocus, bool medicationMode) {
  if (medicationMode || clinicalFocus.any((f) => f.startsWith('medication'))) {
    return 'a pharmacotherapy and medication-safety inquiry';
  }
  if (clinicalFocus.any((f) => f.startsWith('reported symptoms'))) {
    return 'an acute or sub-acute symptom assessment discussion';
  }
  if (clinicalFocus.any((f) => f.startsWith('clinical context'))) {
    return 'a chronic or systemic condition education topic';
  }
  return 'a general preventive health and wellness consultation';
}

String _managementPlan(List<String> clinicalFocus, bool medicationMode) {
  if (medicationMode || clinicalFocus.any((f) => f.contains('medication'))) {
    return 'verify dose and timing, review food and drug interactions, avoid abrupt discontinuation, '
        'and keep a written list of all current prescriptions for your next clinic visit';
  }
  if (clinicalFocus.any((f) => f.contains('symptoms'))) {
    return 'maintain adequate hydration and rest, use clinician-approved symptomatic relief when appropriate, '
        'track severity on a simple 0–10 scale, and seek in-person care if pain or fever escalates';
  }
  if (clinicalFocus.any((f) => f.contains('clinical context'))) {
    return 'adhere to prescribed follow-up intervals, document symptom patterns, '
        'and coordinate laboratory or imaging results with your treating physician';
  }
  return 'maintain balanced nutrition, regular sleep, scheduled screenings, '
      'and prompt reporting of any new or persistent health changes to your care team';
}

String _monitoringAdvice(List<String> clinicalFocus) {
  if (clinicalFocus.any((f) => f.contains('fever') || f.contains('pain'))) {
    return 'seek urgent review if symptoms persist beyond 48–72 hours, become severe, or are accompanied by chest pain, confusion, or breathing difficulty.';
  }
  if (clinicalFocus.any((f) => f.contains('medication'))) {
    return 'report rash, swelling, dizziness, or gastrointestinal upset to your pharmacist or doctor without delay.';
  }
  return 'book a routine appointment if concerns continue or interfere with daily activities.';
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

const _symptomLexicon = {
  'pain': 'pain',
  'ache': 'pain',
  'fever': 'fever',
  'temperature': 'fever',
  'cough': 'coughing',
  'coughing': 'coughing',
  'headache': 'headache',
  'nausea': 'nausea',
  'vomit': 'nausea',
  'vomiting': 'nausea',
  'dizziness': 'dizziness',
  'fatigue': 'fatigue',
  'tired': 'fatigue',
  'rash': 'skin rash',
  'shortness': 'breathlessness',
  'breathless': 'breathlessness',
  'breathing': 'breathlessness',
  'swelling': 'swelling',
  'diarrhea': 'diarrhea',
  'constipation': 'constipation',
  'insomnia': 'sleep disturbance',
  'sleep': 'sleep disturbance',
  'anxiety': 'anxiety',
  'depression': 'low mood',
  'bleeding': 'bleeding',
  'infection': 'infection',
  'inflammation': 'inflammation',
  'ألم': 'pain',
  'حمى': 'fever',
  'سعال': 'coughing',
  'صداع': 'headache',
};

const _medicationLexicon = {
  'paracetamol': 'paracetamol',
  'acetaminophen': 'paracetamol',
  'ibuprofen': 'ibuprofen',
  'aspirin': 'aspirin',
  'amoxicillin': 'amoxicillin',
  'antibiotic': 'antibiotic therapy',
  'antibiotics': 'antibiotic therapy',
  'insulin': 'insulin',
  'metformin': 'metformin',
  'omeprazole': 'omeprazole',
  'antihistamine': 'antihistamine',
  'inhaler': 'inhaled bronchodilator',
  'tablet': 'oral medication',
  'capsule': 'oral medication',
  'prescription': 'prescription medication',
  'medicine': 'medication',
  'medication': 'medication',
  'drug': 'medication',
  'دواء': 'medication',
  'علاج': 'medication',
};

const _conditionLexicon = {
  'diabetes': 'diabetes mellitus',
  'hypertension': 'hypertension',
  'pressure': 'blood pressure disorder',
  'asthma': 'asthma',
  'copd': 'COPD',
  'arthritis': 'arthritis',
  'migraine': 'migraine',
  'infection': 'infectious disease',
  'flu': 'influenza',
  'cold': 'upper respiratory infection',
  'covid': 'COVID-19',
  'pregnancy': 'pregnancy-related care',
  'allergy': 'allergic condition',
  'cholesterol': 'dyslipidemia',
  'anemia': 'anemia',
  'سكري': 'diabetes mellitus',
  'ضغط': 'hypertension',
};

const _vitalLexicon = {
  'bp': 'blood pressure',
  'heart': 'cardiovascular status',
  'pulse': 'heart rate',
  'oxygen': 'oxygen saturation',
  'spo2': 'oxygen saturation',
  'weight': 'body weight',
  'glucose': 'blood glucose',
  'sugar': 'blood glucose',
};
