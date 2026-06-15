import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/responsive_layout.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kSheetBg = Color(0xFF141A17);
const Color _kFieldFill = Color(0xFF161A18);

const _weekOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _dayEn = {
  'Mon': 'Monday',
  'Tue': 'Tuesday',
  'Wed': 'Wednesday',
  'Thu': 'Thursday',
  'Fri': 'Friday',
  'Sat': 'Saturday',
  'Sun': 'Sunday',
};

const _dayAr = {
  'Mon': 'الإثنين',
  'Tue': 'الثلاثاء',
  'Wed': 'الأربعاء',
  'Thu': 'الخميس',
  'Fri': 'الجمعة',
  'Sat': 'السبت',
  'Sun': 'الأحد',
};

/// One row in the schedule breakdown table.
class ScheduleDayEntry {
  ScheduleDayEntry({
    required this.dayKey,
    required this.dayLabel,
    required this.enabled,
    required this.start,
    required this.end,
  });

  final String dayKey;
  final String dayLabel;
  final bool enabled;
  final String start;
  final String end;

  String get rangeLabel => enabled ? '$start – $end' : '—';
}

List<ScheduleDayEntry> parseScheduleBreakdown(Map<String, dynamic> request) {
  final fromApi = request['scheduleBreakdown'];
  if (fromApi is List && fromApi.isNotEmpty) {
    return fromApi.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final key = m['dayKey']?.toString() ?? '';
      return ScheduleDayEntry(
        dayKey: key,
        dayLabel: m['dayLabel']?.toString() ?? _dayEn[key] ?? key,
        enabled: m['enabled'] == true,
        start: m['start']?.toString() ?? '09:00',
        end: m['end']?.toString() ?? '17:00',
      );
    }).toList();
  }

  Map<String, dynamic>? map;
  final dyn = request['dynamicSchedule'] ?? request['proposedScheduleMap'];
  if (dyn is Map) {
    map = Map<String, dynamic>.from(dyn);
  } else if (request['proposedSchedule'] is Map) {
    map = Map<String, dynamic>.from(request['proposedSchedule'] as Map);
  }

  if (map != null) {
    return _weekOrder.map((key) {
      final v = Map<String, dynamic>.from(map![key] as Map? ?? {});
      return ScheduleDayEntry(
        dayKey: key,
        dayLabel: _dayEn[key] ?? key,
        enabled: v['enabled'] == true,
        start: '${v['start'] ?? v['startTime'] ?? '09:00'}',
        end: '${v['end'] ?? v['endTime'] ?? '17:00'}',
      );
    }).toList();
  }

  const jsToKey = {0: 'Sun', 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat'};
  final defaults = {for (final k in _weekOrder) k: ScheduleDayEntry(dayKey: k, dayLabel: _dayEn[k] ?? k, enabled: false, start: '09:00', end: '17:00')};
  final byKey = Map<String, ScheduleDayEntry>.from(defaults);

  final list = request['proposedSchedule'] ?? request['requestedHours'];
  if (list is List) {
    for (final raw in list) {
      if (raw is! Map) continue;
      final dow = int.tryParse('${raw['dayOfWeek']}') ?? -1;
      final key = jsToKey[dow];
      if (key == null) continue;
      byKey[key] = ScheduleDayEntry(
        dayKey: key,
        dayLabel: raw['dayName']?.toString() ?? _dayEn[key] ?? key,
        enabled: true,
        start: '${raw['startTime'] ?? raw['start'] ?? '09:00'}',
        end: '${raw['endTime'] ?? raw['end'] ?? '17:00'}',
      );
    }
  }
  return _weekOrder.map((k) => byKey[k]!).toList();
}

String scheduleInlinePreview(Map<String, dynamic> request, {int maxLen = 72}) {
  final summary = request['scheduleSummary']?.toString().trim();
  if (summary != null && summary.isNotEmpty) {
    return summary.length <= maxLen ? summary : '${summary.substring(0, maxLen)}…';
  }
  final active = parseScheduleBreakdown(request).where((d) => d.enabled).map((d) => '${d.dayKey}: ${d.start}-${d.end}');
  final joined = active.join(', ');
  if (joined.isEmpty) return 'No active days';
  return joined.length <= maxLen ? joined : '${joined.substring(0, maxLen)}…';
}

/// Premium dark/gold dialog — full proposed schedule breakdown.
Future<void> showScheduleChangeReviewDialog(
  BuildContext context, {
  required Map<String, dynamic> request,
  VoidCallback? onApprove,
  VoidCallback? onReject,
}) {
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  final doctor = request['doctorDisplayName']?.toString() ?? '—';
  final created = request['createdAt']?.toString() ?? '';
  final dateLabel = created.length >= 10 ? created.substring(0, 10) : '—';
  final entries = parseScheduleBreakdown(request);
  final activeCount = entries.where((e) => e.enabled).length;
  final wh = request['workingHours'];
  String spanLabel = '';
  if (wh is Map) {
    final s = wh['start']?.toString();
    final e = wh['end']?.toString();
    if (s != null && e != null) spanLabel = '$s – $e';
  }

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => AlertDialog(
      backgroundColor: _kSheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _kGold, width: 1.2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Column(
        children: [
          Text(
            isAr ? 'تفاصيل طلب تعديل الدوام' : 'Schedule change details',
            style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w700, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(doctor, style: GoogleFonts.urbanist(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          Text(
            isAr ? 'تاريخ الطلب: $dateLabel' : 'Requested: $dateLabel',
            style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      content: SizedBox(
        width: RafeeqResponsive.of(context).dialogContentWidth(desktopMax: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (spanLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    isAr ? 'النطاق العام: $spanLabel' : 'Overall span: $spanLabel',
                    style: GoogleFonts.urbanist(color: _kGold.withValues(alpha: 0.9), fontSize: 13),
                  ),
                ),
              Text(
                isAr ? '$activeCount أيام نشطة' : '$activeCount active day(s)',
                style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: _kFieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGold.withValues(alpha: 0.45)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isAr ? 'اليوم' : 'Day',
                            style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            isAr ? 'الدوام' : 'Hours',
                            style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700, fontSize: 12),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0x33D4AF37), height: 16),
                    ...entries.map((day) {
                      final label = isAr ? (_dayAr[day.dayKey] ?? day.dayLabel) : day.dayLabel;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  day.enabled ? Icons.check_circle_outline : Icons.cancel_outlined,
                                  size: 16,
                                  color: day.enabled ? _kGold : Colors.white24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  label,
                                  style: GoogleFonts.urbanist(
                                    color: day.enabled ? _kGoldLight : Colors.white38,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              day.enabled ? day.rangeLabel : (isAr ? 'غير نشط' : 'Off'),
                              style: GoogleFonts.urbanist(
                                color: day.enabled ? Colors.white : Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(isAr ? 'إغلاق' : 'Close', style: GoogleFonts.urbanist(color: Colors.white54)),
        ),
        if (onReject != null)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onReject();
            },
            child: Text(isAr ? 'رفض' : 'Reject', style: GoogleFonts.urbanist(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        if (onApprove != null)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onApprove();
            },
            child: Text(isAr ? 'موافقة' : 'Approve', style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700)),
          ),
      ],
    ),
  );
}
