import '../../../utils/allergy_display.dart';

class VisitPrescriptionRecord {
  const VisitPrescriptionRecord({
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.durationInDays,
    this.instructions = '',
    this.status = 'Active',
  });

  final String medicationName;
  final String dosage;
  final String frequency;
  final String duration;
  final int? durationInDays;
  final String instructions;
  final String status;

  factory VisitPrescriptionRecord.fromJson(Map<String, dynamic> json) {
    return VisitPrescriptionRecord(
      medicationName: json['medicationName']?.toString() ?? 'Medication',
      dosage: json['dosage']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      durationInDays: (json['durationInDays'] as num?)?.toInt(),
      instructions: json['instructions']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
    );
  }
}

class VisitDiagnosisRecord {
  const VisitDiagnosisRecord({
    required this.condition,
    required this.symptoms,
    required this.severity,
    required this.treatmentPlan,
    this.notes = '',
  });

  final String condition;
  final List<String> symptoms;
  final String severity;
  final String treatmentPlan;
  final String notes;

  factory VisitDiagnosisRecord.fromJson(Map<String, dynamic> json) {
    final symptomsRaw = json['symptoms'];
    final symptoms = symptomsRaw is List
        ? symptomsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    return VisitDiagnosisRecord(
      condition: json['condition']?.toString() ?? '',
      symptoms: symptoms,
      severity: json['severity']?.toString() ?? 'Moderate',
      treatmentPlan: json['treatmentPlan']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class PatientVisitHistoryEntry {
  const PatientVisitHistoryEntry({
    required this.id,
    required this.visitDate,
    required this.status,
    this.diagnosis,
    required this.prescriptions,
  });

  final String id;
  final DateTime? visitDate;
  final String status;
  final VisitDiagnosisRecord? diagnosis;
  final List<VisitPrescriptionRecord> prescriptions;

  factory PatientVisitHistoryEntry.fromJson(Map<String, dynamic> json) {
    final dxRaw = json['diagnosis'];
    final rxRaw = json['prescriptions'] as List<dynamic>? ?? [];

    return PatientVisitHistoryEntry(
      id: json['id']?.toString() ?? '',
      visitDate: DateTime.tryParse(json['visitDate']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'Recorded',
      diagnosis: dxRaw is Map ? VisitDiagnosisRecord.fromJson(Map<String, dynamic>.from(dxRaw)) : null,
      prescriptions: [
        for (final entry in rxRaw)
          if (entry is Map) VisitPrescriptionRecord.fromJson(Map<String, dynamic>.from(entry)),
      ],
    );
  }
}

class PatientMedicalProfile {
  const PatientMedicalProfile({
    required this.patientId,
    required this.patientName,
    required this.allergiesDisplay,
    required this.activeMedicationCount,
    required this.visits,
  });

  final String patientId;
  final String patientName;
  final String allergiesDisplay;
  final int activeMedicationCount;
  final List<PatientVisitHistoryEntry> visits;

  factory PatientMedicalProfile.fromEmrJson({
    required String patientId,
    required String patientName,
    required Map<String, dynamic> emr,
  }) {
    final timeline = emr['visitTimeline'] as List<dynamic>? ?? [];
    final visits = <PatientVisitHistoryEntry>[
      for (final entry in timeline)
        if (entry is Map) PatientVisitHistoryEntry.fromJson(Map<String, dynamic>.from(entry)),
    ];

    final allergiesRaw = emr['allergies'];
    final activeMeds = emr['activeMedications'] as List<dynamic>? ?? [];

    return PatientMedicalProfile(
      patientId: patientId,
      patientName: patientName,
      allergiesDisplay: formatAllergiesForDisplay(allergiesRaw, emptyPlaceholder: 'None recorded'),
      activeMedicationCount: activeMeds.length,
      visits: visits,
    );
  }
}
