/// Strips CDSS/ADR metadata from stored allergy strings for clean UI labels.
library;

/// Extracts plain medication names from raw allergy entries (lists or strings).
List<String> parseAllergyMedicationNames(dynamic raw) {
  final names = <String>[];

  void addFromString(String s) {
    for (final part in s.split(RegExp(r'[,;]'))) {
      final cleaned = _cleanAllergyEntry(part);
      if (cleaned.isNotEmpty) names.add(cleaned);
    }
  }

  if (raw is List) {
    for (final e in raw) {
      addFromString(e.toString());
    }
  } else if (raw != null) {
    addFromString(raw.toString());
  }

  final seen = <String>{};
  final unique = <String>[];
  for (final n in names) {
    final key = n.toLowerCase();
    if (!seen.contains(key)) {
      seen.add(key);
      unique.add(n);
    }
  }
  return unique;
}

/// Comma-separated display for profile/detail views, e.g. `Paracetamol, premonor, acamol`.
String formatAllergiesForDisplay(dynamic raw, {String emptyPlaceholder = '—'}) {
  final names = parseAllergyMedicationNames(raw);
  if (names.isEmpty) return emptyPlaceholder;
  return names.join(', ');
}

String _cleanAllergyEntry(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';

  // Remove bracketed metadata: [class: allergy], etc.
  s = s.replaceAll(RegExp(r'\s*\[[^\]]*\]\s*', caseSensitive: false), ' ').trim();

  // Medication name is before em dash / en dash / hyphen-separated suffixes.
  final parts = s.split(RegExp(r'\s*[—–-]\s*'));
  if (parts.isNotEmpty) {
    s = parts.first.trim();
  }

  // Remove parenthetical ADR / date / severity notes.
  s = s.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ').trim();

  // Drop trailing severity tokens sometimes stored without parentheses.
  s = s.replaceAll(
    RegExp(r'\s+(Unknown|Severe|Moderate|Mild|Critical)\s*$', caseSensitive: false),
    '',
  ).trim();

  // Remove "ADR confirmed" fragments if any remain inline.
  s = s.replaceAll(RegExp(r'\bADR\s+confirmed\b[^,;]*', caseSensitive: false), '').trim();
  s = s.replaceAll(RegExp(r'\bconfirmed\b\s*\d{4}[-/]\d{2}[-/]\d{2}'), '').trim();

  return s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}
