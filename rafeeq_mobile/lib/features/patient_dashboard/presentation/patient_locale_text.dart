import 'package:flutter/material.dart';

/// True when the active app locale is Arabic.
bool patientIsArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

/// Pick the English or Arabic segment from bilingual DB/UI strings (e.g. "Nablus - نابلس").
String patientLocaleSegment(String raw, {required bool isArabic}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  final parts = trimmed.split(RegExp(r'\s*[·\-–—/|]\s*')).where((p) => p.trim().isNotEmpty).toList();
  if (parts.length <= 1) {
    if (isArabic) return trimmed;
    return _stripArabic(trimmed);
  }

  bool hasArabic(String t) => RegExp(r'[\u0600-\u06FF]').hasMatch(t);
  bool hasLatin(String t) => RegExp(r'[A-Za-z]').hasMatch(t);

  if (isArabic) {
    final arParts = parts.where((p) => hasArabic(p)).toList();
    if (arParts.isNotEmpty) return arParts.join(' · ');
    return trimmed;
  }

  final enParts = parts.where((p) => hasLatin(p) && !hasArabic(p)).toList();
  if (enParts.isNotEmpty) return enParts.join(' · ');
  return _stripArabic(trimmed);
}

String _stripArabic(String s) =>
    s.replaceAll(RegExp(r'[\u0600-\u06FF]+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Localize backend routing status messages when they are English-only.
String patientRoutingMessage(String? backendMessage, {required bool isArabic}) {
  final msg = backendMessage?.trim() ?? '';
  if (msg.isEmpty) return msg;
  if (isArabic) {
    switch (msg) {
      case 'Available at your clinic pharmacy.':
        return 'متوفر في صيدلية العيادة.';
      case 'Not available in clinic pharmacy. Browse nearby pharmacies holding this item:':
        return 'غير متوفر في صيدلية العيادة. تصفح الصيدليات المجاورة التي توفر هذا الدواء:';
      case 'This clinic routes purchases through registered community pharmacies.':
        return 'توجّه هذه العيادة المشتريات عبر الصيدليات المجتمعية المسجلة.';
      default:
        return msg;
    }
  }
  return msg;
}
