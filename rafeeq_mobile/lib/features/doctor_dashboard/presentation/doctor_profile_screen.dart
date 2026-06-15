import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/app_localizations.dart';
import '../../../tenant_state.dart';
import '../data/doctor_portal_api.dart';
import 'doctor_clinic_services_screen.dart';
import '../../billing/models/doctor_billing_profile.dart';
import '../data/doctor_workspace_api.dart';

const Color _kWorkspaceBlack = Color(0xFF0A0F0D);
const Color _kFieldFill = Color(0xFF161A18);
const Color _kFieldFillReadOnly = Color(0xFF121614);
const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kGoldDeep = Color(0xFFB8860B);
const Color _kSheetBg = Color(0xFF141A17);

const _weekKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _jsToKey = {0: 'Sun', 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat'};

const _leaveTypes = [
  'Annual Leave',
  'Sick Leave',
  'Short Permission / Emergency Leave',
];

Map<String, dynamic> _defaultDynamicSchedule() {
  final m = <String, dynamic>{};
  for (final k in _weekKeys) {
    m[k] = {'enabled': false, 'start': '09:00', 'end': '17:00'};
  }
  for (final k in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
    m[k] = {'enabled': true, 'start': '09:00', 'end': '17:00'};
  }
  return m;
}

Map<String, dynamic> _scheduleFromProfile(Map<String, dynamic> m) {
  final dyn = m['dynamicSchedule'];
  if (dyn is Map) {
    return jsonDecode(jsonEncode(Map<String, dynamic>.from(dyn))) as Map<String, dynamic>;
  }
  final sched = m['workSchedule'];
  if (sched is! List) return _defaultDynamicSchedule();
  final out = _defaultDynamicSchedule();
  for (final raw in sched) {
    if (raw is! Map) continue;
    final dow = int.tryParse('${raw['dayOfWeek']}') ?? -1;
    final key = _jsToKey[dow];
    if (key == null) continue;
    out[key] = {
      'enabled': true,
      'start': '${raw['startTime'] ?? raw['start'] ?? '09:00'}',
      'end': '${raw['endTime'] ?? raw['end'] ?? '17:00'}',
    };
  }
  return out;
}

String _dayLabel(String key, bool isAr) {
  if (!isAr) {
    const en = {
      'Mon': 'Monday',
      'Tue': 'Tuesday',
      'Wed': 'Wednesday',
      'Thu': 'Thursday',
      'Fri': 'Friday',
      'Sat': 'Saturday',
      'Sun': 'Sunday',
    };
    return en[key] ?? key;
  }
  const ar = {
    'Mon': 'الإثنين',
    'Tue': 'الثلاثاء',
    'Wed': 'الأربعاء',
    'Thu': 'الخميس',
    'Fri': 'الجمعة',
    'Sat': 'السبت',
    'Sun': 'الأحد',
  };
  return ar[key] ?? key;
}

TimeOfDay _parseHm(String hm) {
  final p = hm.split(':');
  if (p.length < 2) return const TimeOfDay(hour: 9, minute: 0);
  return TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0);
}

String _hmFromTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _formatDisplayTime(String hm) {
  final t = _parseHm(hm);
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$h:${t.minute.toString().padLeft(2, '0')} $ap';
}

String _formatConsultationFee(dynamic raw) {
  final fee = DoctorBillingProfile.parseConsultationFee(raw, fallback: 0);
  if (fee <= 0) return '';
  return fee.truncateToDouble() == fee ? '${fee.toInt()}' : fee.toStringAsFixed(2);
}

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key, required this.doctorUserId});

  final String doctorUserId;

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _name = TextEditingController();
  final _spec = TextEditingController();
  final _years = TextEditingController();
  final _clinicId = TextEditingController();
  final _certs = TextEditingController();
  final _fee = TextEditingController();
  Map<String, dynamic> _dynamicSchedule = _defaultDynamicSchedule();
  Map<String, dynamic> _initialSchedule = _defaultDynamicSchedule();
  late final DoctorWorkspaceApi _workspaceApi;
  bool _loading = true;
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _spec.dispose();
    _years.dispose();
    _clinicId.dispose();
    _certs.dispose();
    _fee.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _workspaceApi = DoctorWorkspaceApi(doctorUserId: widget.doctorUserId);
    _load();
  }

  InputDecoration _dec(String label, {bool readOnly = false}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _kGold.withValues(alpha: readOnly ? 0.35 : 0.65)),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: readOnly ? _kGold.withValues(alpha: 0.45) : _kGold.withValues(alpha: 0.85)),
      filled: true,
      fillColor: readOnly ? _kFieldFillReadOnly : _kFieldFill,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: _kGold, width: readOnly ? 1 : 1.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  TextStyle get _fieldText => GoogleFonts.urbanist(color: Colors.white, fontSize: 15);
  TextStyle get _fieldTextReadOnly => GoogleFonts.urbanist(color: Colors.white54, fontSize: 15);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      if (TenantState.instance.orgId.isEmpty) {
        throw Exception('Organization context missing. Please log out and sign in again.');
      }
      final m = await DoctorPortalApi.getProfile(widget.doctorUserId);
      if (!mounted) return;
      _name.text = m['displayName']?.toString() ?? m['fullName']?.toString() ?? '';
      _spec.text = m['specialization']?.toString() ?? m['specialty']?.toString() ?? '';
      _years.text = '${m['yearsExperience'] ?? m['yearsOfExperience'] ?? ''}';
      _clinicId.text = m['clinicName']?.toString().trim().isNotEmpty == true
          ? m['clinicName'].toString()
          : m['currentClinic']?.toString().trim().isNotEmpty == true
              ? m['currentClinic'].toString()
              : m['organizationName']?.toString().trim().isNotEmpty == true
                  ? m['organizationName'].toString()
                  : m['clinicId']?.toString() ?? m['doctorClinicId']?.toString() ?? '';
      _certs.text = (m['certifications'] as List<dynamic>? ?? []).join(', ');
      _fee.text = _formatConsultationFee(m['consultationFee']);
      final sched = _scheduleFromProfile(Map<String, dynamic>.from(m));
      _dynamicSchedule = sched;
      _initialSchedule = jsonDecode(jsonEncode(sched)) as Map<String, dynamic>;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  bool _scheduleChanged() => jsonEncode(_dynamicSchedule) != jsonEncode(_initialSchedule);

  void _applyStandardSchedule(AppLocalizations l10n) {
    setState(() => _dynamicSchedule = _defaultDynamicSchedule());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.doctorScheduleApplied, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1510),
      ),
    );
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _kGold,
              onPrimary: _kWorkspaceBlack,
              surface: _kSheetBg,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: _kSheetBg),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  Future<void> _editDayTime(String dayKey, bool isStart) async {
    final day = Map<String, dynamic>.from(_dynamicSchedule[dayKey] as Map? ?? {});
    final hm = isStart ? '${day['start'] ?? '09:00'}' : '${day['end'] ?? '17:00'}';
    final picked = await _pickTime(_parseHm(hm));
    if (picked == null || !mounted) return;
    setState(() {
      day[isStart ? 'start' : 'end'] = _hmFromTime(picked);
      day['enabled'] = true;
      _dynamicSchedule[dayKey] = day;
    });
  }

  Widget _goldCheckbox({required bool value, required ValueChanged<bool?> onChanged}) {
    return Theme(
      data: ThemeData.dark().copyWith(
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _kGold;
            return _kFieldFill;
          }),
          side: BorderSide(color: _kGold.withValues(alpha: 0.85), width: 1.5),
          checkColor: WidgetStateProperty.all(_kWorkspaceBlack),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      child: Checkbox(value: value, onChanged: onChanged),
    );
  }

  Widget _dayScheduleRow(String dayKey, bool isAr) {
    final day = Map<String, dynamic>.from(_dynamicSchedule[dayKey] as Map? ?? {'enabled': false});
    final enabled = day['enabled'] == true;
    final start = '${day['start'] ?? '09:00'}';
    final end = '${day['end'] ?? '17:00'}';
    final rangeLabel = enabled ? '${_formatDisplayTime(start)} – ${_formatDisplayTime(end)}' : (isAr ? 'غير نشط' : 'Off');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGold.withValues(alpha: enabled ? 0.55 : 0.25)),
      ),
      child: Row(
        children: [
          _goldCheckbox(
            value: enabled,
            onChanged: (v) {
              setState(() {
                day['enabled'] = v == true;
                if (v == true) {
                  day['start'] ??= '09:00';
                  day['end'] ??= '17:00';
                }
                _dynamicSchedule[dayKey] = day;
              });
            },
          ),
          Expanded(
            flex: 2,
            child: Text(_dayLabel(dayKey, isAr), style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          if (enabled) ...[
            _timeChip(isAr ? 'بداية' : 'Start', start, () => _editDayTime(dayKey, true)),
            const SizedBox(width: 6),
            _timeChip(isAr ? 'نهاية' : 'End', end, () => _editDayTime(dayKey, false)),
          ] else
            Expanded(
              flex: 3,
              child: Text(rangeLabel, style: GoogleFonts.urbanist(color: Colors.white38, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _timeChip(String label, String hm, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: _kGold.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.urbanist(color: _kGold.withValues(alpha: 0.7), fontSize: 10)),
              Text(_formatDisplayTime(hm), style: GoogleFonts.urbanist(color: _kGoldLight, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 900, imageQuality: 82);
    if (x == null) return;
    final b64 = base64Encode(await x.readAsBytes());
    try {
      await DoctorPortalApi.putProfile(widget.doctorUserId, {
        'profileImageBase64': 'data:image/jpeg;base64,$b64',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.doctorProfileSaved),
            backgroundColor: const Color(0xFF1A1510),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showScheduleRequestDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSheetBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _kGold)),
        title: Text('طلب تعديل الدوام', style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        content: Text(
          'طلبك لتعديل الدوام أُرسل بنجاح بانتظار موافقة آدمن العيادة.',
          style: GoogleFonts.urbanist(color: Colors.white70, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('حسناً', style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _openLeaveSheet(bool isAr) async {
    String leaveType = _leaveTypes.first;
    DateTime? start;
    DateTime? end;
    final reasonCtrl = TextEditingController();
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: _kSheetBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(top: BorderSide(color: _kGold, width: 1.2)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _kGold.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isAr ? 'طلب إجازة أو مغادرة' : 'Request Leave / Permission',
                        style: GoogleFonts.urbanist(color: _kGold, fontSize: 18, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: leaveType,
                        dropdownColor: _kFieldFill,
                        style: _fieldText,
                        decoration: _dec(isAr ? 'نوع الطلب' : 'Request type'),
                        items: _leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setSheet(() => leaveType = v ?? leaveType),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: sheetCtx,
                                  initialDate: start ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  builder: (c, ch) => Theme(
                                    data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _kGold, surface: _kSheetBg)),
                                    child: ch ?? const SizedBox.shrink(),
                                  ),
                                );
                                if (d != null) setSheet(() => start = d);
                              },
                              style: OutlinedButton.styleFrom(side: BorderSide(color: _kGold.withValues(alpha: 0.6)), foregroundColor: _kGoldLight),
                              child: Text(start == null ? (isAr ? 'تاريخ البداية' : 'Start date') : '${start!.year}-${start!.month.toString().padLeft(2, '0')}-${start!.day.toString().padLeft(2, '0')}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: sheetCtx,
                                  initialDate: end ?? start ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  builder: (c, ch) => Theme(
                                    data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _kGold, surface: _kSheetBg)),
                                    child: ch ?? const SizedBox.shrink(),
                                  ),
                                );
                                if (d != null) setSheet(() => end = d);
                              },
                              style: OutlinedButton.styleFrom(side: BorderSide(color: _kGold.withValues(alpha: 0.6)), foregroundColor: _kGoldLight),
                              child: Text(end == null ? (isAr ? 'تاريخ النهاية' : 'End date') : '${end!.year}-${end!.month.toString().padLeft(2, '0')}-${end!.day.toString().padLeft(2, '0')}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonCtrl,
                        style: _fieldText,
                        cursorColor: _kGold,
                        maxLines: 3,
                        decoration: _dec(isAr ? 'السبب / ملاحظات (اختياري)' : 'Reason / notes (optional)'),
                      ),
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: submitting
                              ? null
                              : () async {
                                  if (start == null || end == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(isAr ? 'اختر تاريخ البداية والنهاية' : 'Select start and end dates')),
                                    );
                                    return;
                                  }
                                  setSheet(() => submitting = true);
                                  try {
                                    final s = '${start!.year}-${start!.month.toString().padLeft(2, '0')}-${start!.day.toString().padLeft(2, '0')}';
                                    final e = '${end!.year}-${end!.month.toString().padLeft(2, '0')}-${end!.day.toString().padLeft(2, '0')}';
                                    await _workspaceApi.postLeaveRequest(
                                      type: leaveType,
                                      startDate: s,
                                      endDate: e,
                                      reason: reasonCtrl.text.trim(),
                                    );
                                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isAr ? 'تم إرسال طلب الإجازة بانتظار موافقة الإدارة' : 'Leave request submitted for admin approval'),
                                          backgroundColor: const Color(0xFF1A1510),
                                        ),
                                      );
                                    }
                                  } catch (err) {
                                    setSheet(() => submitting = false);
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
                                  }
                                },
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(colors: [_kGoldLight, _kGold, _kGoldDeep]),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: submitting
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _kWorkspaceBlack))
                                  : Text(isAr ? 'إرسال الطلب' : 'Submit request', style: GoogleFonts.urbanist(color: _kWorkspaceBlack, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    reasonCtrl.dispose();
  }


  Future<void> _save(AppLocalizations l10n) async {
    setState(() => _saving = true);
    try {
      final scheduleChanged = _scheduleChanged();
      if (scheduleChanged) {
        await _workspaceApi.postScheduleRequest(Map<String, dynamic>.from(_dynamicSchedule));
        if (mounted) await _showScheduleRequestDialog();
      }

      final feeParsed = num.tryParse(_fee.text.trim());
      await DoctorPortalApi.putProfile(widget.doctorUserId, {
        'certifications': _certs.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        if (feeParsed != null && feeParsed > 0) 'consultationFee': feeParsed,
      });

      if (scheduleChanged && mounted) {
        setState(() => _initialSchedule = jsonDecode(jsonEncode(_dynamicSchedule)) as Map<String, dynamic>);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.doctorProfileSaved), backgroundColor: const Color(0xFF1A1510)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _goldSaveButton(AppLocalizations l10n) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _saving ? null : () => _save(l10n),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(colors: [_kGoldLight, _kGold, _kGoldDeep, _kGold], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: _kGold.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _saving
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _kWorkspaceBlack))
                : Text(l10n.doctorSaveProfile, style: GoogleFonts.urbanist(color: _kWorkspaceBlack, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final clinicLabel = isAr ? 'العيادة / المنشأة' : 'Clinic / Facility';
    final scheduleTitle = isAr ? 'أوقات الدوام' : 'Working hours';
    final enabledDays = _weekKeys.where((k) => (_dynamicSchedule[k] as Map?)?['enabled'] == true).length;

    return Scaffold(
      backgroundColor: _kWorkspaceBlack,
      appBar: AppBar(
        backgroundColor: _kWorkspaceBlack,
        foregroundColor: _kGoldLight,
        elevation: 0,
        title: Text(l10n.doctorProfileTitle, style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kGold))
          : _err != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_err!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _load, child: Text(l10n.doctorRetry, style: const TextStyle(color: _kGold))),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(isAr ? 'بيانات مؤسسية (للعرض فقط)' : 'Institutional fields (read-only)',
                          style: GoogleFonts.urbanist(color: _kGold.withValues(alpha: 0.9), fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 10),
                      TextFormField(controller: _name, readOnly: true, style: _fieldTextReadOnly, decoration: _dec(l10n.doctorFieldDisplayName, readOnly: true)),
                      const SizedBox(height: 10),
                      TextFormField(controller: _spec, readOnly: true, style: _fieldTextReadOnly, decoration: _dec(l10n.doctorFieldSpecialization, readOnly: true)),
                      const SizedBox(height: 10),
                      TextFormField(controller: _years, readOnly: true, style: _fieldTextReadOnly, keyboardType: TextInputType.number, decoration: _dec(l10n.doctorFieldYears, readOnly: true)),
                      const SizedBox(height: 10),
                      TextFormField(controller: _clinicId, readOnly: true, style: _fieldTextReadOnly, decoration: _dec(clinicLabel, readOnly: true)),
                      const SizedBox(height: 20),
                      Text(isAr ? 'حقول قابلة للتعديل' : 'Editable profile',
                          style: GoogleFonts.urbanist(color: _kGold.withValues(alpha: 0.9), fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 10),
                      TextFormField(controller: _certs, style: _fieldText, cursorColor: _kGold, decoration: _dec(l10n.doctorFieldCertifications)),
                      const SizedBox(height: 10),
                      TextFormField(controller: _fee, style: _fieldText, cursorColor: _kGold, keyboardType: TextInputType.number, decoration: _dec(l10n.doctorFieldFee)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => DoctorClinicServicesScreen(doctorUserId: widget.doctorUserId),
                            ),
                          ).then((_) => _load());
                        },
                        icon: const Icon(Icons.medical_services_outlined, color: _kGoldLight),
                        label: Text(
                          isAr ? 'العيادة والخدمات — الأسعار والفوترة' : 'Clinic & Services — pricing & billing',
                          style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _kGold.withValues(alpha: 0.75)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.photo_camera_outlined, color: _kGoldLight),
                        label: Text(l10n.doctorPickPhoto, style: GoogleFonts.urbanist(color: _kGoldLight)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: _kGold.withValues(alpha: 0.75)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      const SizedBox(height: 20),
                      Text(scheduleTitle, style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(
                        isAr ? 'تعديل الدوام يتطلب موافقة إدارة العيادة.' : 'Schedule edits require clinic admin approval.',
                        style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => _applyStandardSchedule(l10n),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: _kGold.withValues(alpha: 0.6)), foregroundColor: _kGoldLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text(l10n.doctorApplySchedule, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 12),
                      ..._weekKeys.map((k) => _dayScheduleRow(k, isAr)),
                      Text('$enabledDays ${isAr ? 'أيام نشطة' : 'active day(s)'}', style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _openLeaveSheet(isAr),
                        icon: const Icon(Icons.event_busy_outlined, color: _kGoldLight),
                        label: Text(
                          isAr ? 'طلب إجازة أو مغادرة' : 'Request Leave / Permission',
                          style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _kGold),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _goldSaveButton(l10n),
                    ],
                  ),
                ),
    );
  }
}
