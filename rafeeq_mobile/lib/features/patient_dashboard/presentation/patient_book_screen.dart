import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../api_config.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../tenant_state.dart';
import '../data/patient_portal_api.dart';
import 'patient_theme.dart';

/// Slot status from API (`isBooked` / `status` field).
enum _SlotStatus { available, booked }

class _SlotUi {
  const _SlotUi({
    required this.displayTime,
    required this.apiTime,
    required this.status,
    required this.slotId,
    this.waitingList = const [],
  });

  final String displayTime;
  final String apiTime;
  final _SlotStatus status;
  final String slotId;
  final List<String> waitingList;

  bool get isAvailable => status == _SlotStatus.available;
  bool get isBooked => status == _SlotStatus.booked;

  bool isPatientWaiting(String patientUserId) {
    final pid = patientUserId.trim();
    if (pid.isEmpty) return false;
    return waitingList.any((id) => id.trim() == pid);
  }

  _SlotUi withPatientOnWaitingList(String patientUserId) {
    if (isPatientWaiting(patientUserId)) return this;
    return _SlotUi(
      displayTime: displayTime,
      apiTime: apiTime,
      status: status,
      slotId: slotId,
      waitingList: [...waitingList, patientUserId],
    );
  }
}

/// Book tab: doctor → available dates → time slots (waitlist).
class PatientBookingTab extends StatefulWidget {
  const PatientBookingTab({
    super.key,
    required this.patientUserId,
    this.initialDoctorUserId,
    this.initialDoctorName,
  });

  final String patientUserId;
  final String? initialDoctorUserId;
  final String? initialDoctorName;

  @override
  State<PatientBookingTab> createState() => _PatientBookingTabState();
}

class _PatientBookingTabState extends State<PatientBookingTab> {
  /// How far ahead to scan for doctor working days with real slots.
  static const int _activeDaysHorizon = 60;

  String? _clinicId;
  List<Map<String, dynamic>> _doctors = [];
  String? _selectedDoctorId;
  String _selectedDoctorName = '';

  List<DateTime> _availableDates = [];
  DateTime? _selectedDate;

  List<_SlotUi> _slots = [];
  bool _onLeave = false;
  bool _hasSchedule = true;

  bool _loading = true;
  bool _datesLoading = false;
  bool _slotsLoading = false;
  bool _actionBusy = false;
  String _patientName = 'Patient';
  String? _err;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _doctorDisplayName(Map<String, dynamic> doctor) {
    final raw = doctor['name']?.toString().trim() ?? 'Doctor';
    if (raw.isEmpty) return 'Doctor';
    final lower = raw.toLowerCase();
    if (lower.startsWith('dr.') || lower.startsWith('dr ')) return raw;
    return 'Dr. $raw';
  }

  static String _toYmd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static DateTime? _parseYmd(String raw) {
    final p = DateTime.tryParse(raw.trim());
    if (p == null) return null;
    return _dateOnly(p);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _selectedDoctorId = widget.initialDoctorUserId;
    _selectedDoctorName = widget.initialDoctorName ?? '';
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final orgId = TenantState.instance.orgId;
      if (orgId.isEmpty) throw Exception('Organization not configured');

      final clinicsRes = await http
          .get(Uri.parse('$rafeeqApiBase/api/clinics?orgId=$orgId'))
          .timeout(const Duration(seconds: 15));
      if (clinicsRes.statusCode != 200) throw Exception(clinicsRes.body);
      final clinics = jsonDecode(clinicsRes.body) as List<dynamic>;

      final preferred = TenantState.instance.preferredClinicId.trim();
      if (preferred.isNotEmpty) {
        _clinicId = preferred;
      } else if (clinics.isNotEmpty && clinics.first is Map) {
        _clinicId = (clinics.first as Map)['_id']?.toString();
      }

      try {
        final patientRes = await http
            .get(Uri.parse('$rafeeqApiBase/api/patients/${widget.patientUserId}'))
            .timeout(const Duration(seconds: 10));
        if (patientRes.statusCode == 200) {
          final p = jsonDecode(patientRes.body) as Map<String, dynamic>;
          _patientName = p['fullName']?.toString() ??
              p['name']?.toString() ??
              p['patientName']?.toString() ??
              'Patient';
        }
      } catch (_) {}

      if (_clinicId != null && _clinicId!.isNotEmpty) {
        _doctors = await PatientPortalApi.getBookingDoctors(_clinicId!, orgId: orgId);
      } else {
        _doctors = await PatientPortalApi.getBookingDoctorsByOrg(orgId);
        if (_doctors.isNotEmpty) {
          _clinicId = _doctors.first['clinicId']?.toString();
        }
      }
      if (_doctors.isEmpty) throw Exception('No doctors available for booking');

      if (_selectedDoctorId == null ||
          !_doctors.any((d) => d['userId']?.toString() == _selectedDoctorId)) {
        final first = _doctors.first;
        _selectedDoctorId = first['userId']?.toString();
        _selectedDoctorName = first['name']?.toString() ?? 'Doctor';
      } else {
        final hit = _doctors.firstWhere(
          (d) => d['userId']?.toString() == _selectedDoctorId,
          orElse: () => _doctors.first,
        );
        _selectedDoctorName = hit['name']?.toString() ?? _selectedDoctorName;
      }

      if (!mounted) return;
      setState(() => _loading = false);
      await _onDoctorChanged(_selectedDoctorId!, _selectedDoctorName);
    } catch (e) {
      if (mounted) setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _onDoctorChanged(String doctorId, String doctorName) async {
    setState(() {
      _selectedDoctorId = doctorId;
      _selectedDoctorName = doctorName;
      _availableDates = [];
      _selectedDate = null;
      _slots = [];
      _datesLoading = true;
      _slotsLoading = true;
      _onLeave = false;
      _hasSchedule = true;
    });

    try {
      final ymdList = await PatientPortalApi.getDoctorActiveDays(
        doctorId,
        days: _activeDaysHorizon,
      );
      final dates = <DateTime>[
        for (final y in ymdList)
          if (_parseYmd(y) != null) _parseYmd(y)!,
      ];

      if (!mounted) return;
      setState(() {
        _availableDates = dates;
        _datesLoading = false;
        _selectedDate = dates.isNotEmpty ? dates.first : null;
      });

      if (_selectedDate != null) {
        await _loadSlotsForDate(_selectedDate!);
      } else if (mounted) {
        setState(() => _slotsLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _datesLoading = false;
        _slotsLoading = false;
      });
    }
  }

  Future<void> _loadSlotsForDate(DateTime day) async {
    final doctorId = _selectedDoctorId;
    if (doctorId == null || doctorId.isEmpty) return;

    setState(() => _slotsLoading = true);
    try {
      final payload = await PatientPortalApi.getAppointmentSlots(
        doctorUserId: doctorId,
        dateYmd: _toYmd(day),
      );
      if (!mounted) return;
      setState(() {
        _onLeave = payload['onLeave'] == true;
        _hasSchedule = payload['hasSchedule'] != false;
        _slots = _parseSlotList(payload);
        _slotsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _slotsLoading = false;
      });
    }
  }

  String _buildSlotId(String apiTime) {
    final doctorId = _selectedDoctorId ?? '';
    final date = _selectedDate != null ? _toYmd(_selectedDate!) : '';
    final t = _hhmmFromDisplay(apiTime);
    return '$doctorId|$date|$t';
  }

  List<_SlotUi> _parseSlotList(Map<String, dynamic> raw) {
    final list = raw['availableSlots'] as List<dynamic>? ?? const [];
    final out = <_SlotUi>[];
    for (final entry in list) {
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        final display = (map['time'] ?? map['label'] ?? '').toString().trim();
        final api = (map['value'] ?? _hhmmFromDisplay(display)).toString().trim();
        if (display.isEmpty && api.isEmpty) continue;
        final apiNorm = api.isNotEmpty ? _hhmmFromDisplay(api) : _hhmmFromDisplay(display);
        final slotId = (map['slotId'] ?? _buildSlotId(apiNorm)).toString();
        final rawStatus = map['status']?.toString().toLowerCase() ?? '';
        final booked = map['isBooked'] == true || rawStatus == 'booked';
        final status = booked ? _SlotStatus.booked : _SlotStatus.available;
        final wlRaw = map['waitingList'];
        final waitingList = <String>[
          if (wlRaw is List)
            for (final id in wlRaw)
              if (id != null) id.toString().trim(),
        ];
        out.add(_SlotUi(
          displayTime: display.isNotEmpty ? display : _formatSlot12h(apiNorm),
          apiTime: apiNorm,
          status: status,
          slotId: slotId,
          waitingList: waitingList,
        ));
      }
    }
    return out;
  }

  String _hhmmFromDisplay(String display) {
    final s = display.trim();
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false).firstMatch(s);
    if (m == null) return s;
    var h = int.parse(m.group(1)!);
    final mm = m.group(2)!;
    final period = (m.group(3) ?? '').toUpperCase();
    if (period == 'PM' && h < 12) h += 12;
    if (period == 'AM' && h == 12) h = 0;
    return '${h.toString().padLeft(2, '0')}:$mm';
  }

  String _formatSlot12h(String hhmm) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
    if (m == null) return hhmm;
    var h = int.parse(m.group(1)!);
    final mm = m.group(2)!;
    final period = h >= 12 ? 'PM' : 'AM';
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:$mm $period';
  }

  Future<void> _onDateSelected(DateTime day) async {
    if (_selectedDate != null && _sameDay(day, _selectedDate!)) return;
    setState(() => _selectedDate = _dateOnly(day));
    await _loadSlotsForDate(day);
  }

  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.urbanist(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.urbanist()),
        backgroundColor: const Color(0xFF3A1515),
      ),
    );
  }

  void _showAlreadyOnWaitlistSnack() {
    if (!mounted) return;
    final message = context.l10n.patientAlreadyOnWaitlist;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.amber,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmJoinWaitingList(_SlotUi slot) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final msg = await PatientPortalApi.joinSlotWaitingList(
        patientUserId: widget.patientUserId,
        slotId: slot.slotId,
      );
      if (!mounted) return;
      _showSuccessSnack(msg);
      setState(() {
        final i = _slots.indexWhere((s) => s.slotId == slot.slotId);
        if (i >= 0) {
          _slots[i] = _slots[i].withPatientOnWaitingList(widget.patientUserId);
        }
      });
      if (_selectedDate != null) {
        await _loadSlotsForDate(_selectedDate!);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('already booked or requested')) {
        _showAlreadyOnWaitlistSnack();
      } else {
        _showErrorSnack(msg);
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _showConfirmBookingDialog(_SlotUi slot) async {
    final l10n = context.l10n;
    final dateYmd = _selectedDate != null ? _toYmd(_selectedDate!) : '';
    final dateLabel = _selectedDate != null
        ? DateFormat('EEE, MMM d, yyyy').format(_selectedDate!)
        : dateYmd;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPatientSheetBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kPatientGold.withValues(alpha: 0.45)),
        ),
        title: Text(
          l10n.patientConfirmBookingTitle,
          style: GoogleFonts.urbanist(
            color: kPatientGoldLight,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: Text(
          l10n.patientConfirmBookingBody(_selectedDoctorName, dateLabel, slot.displayTime),
          style: GoogleFonts.urbanist(color: Colors.white70, height: 1.45, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: GoogleFonts.urbanist(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: kPatientGoldDeep,
              foregroundColor: Colors.black,
            ),
            child: Text(l10n.patientConfirmBooking, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _submitBooking(slot);
    }
  }

  Future<void> _submitBooking(_SlotUi slot) async {
    if (_actionBusy || _selectedDate == null || _selectedDoctorId == null) return;
    setState(() => _actionBusy = true);
    try {
      final result = await PatientPortalApi.bookAppointment(
        patientUserId: widget.patientUserId,
        patientName: _patientName,
        dateYmd: _toYmd(_selectedDate!),
        timeHhmm: slot.apiTime,
        doctorUserId: _selectedDoctorId!,
        doctorName: _selectedDoctorName,
        clinicId: _clinicId,
      );
      if (!mounted) return;
      if (result['addedToWaitingList'] == true) {
        final msg = result['message']?.toString().trim();
        _showSuccessSnack(
          msg != null && msg.isNotEmpty ? msg : context.l10n.patientSlotFullWaitlist,
        );
      } else {
        _showSuccessSnack(context.l10n.patientAppointmentBooked(_selectedDoctorName));
      }
      await _loadSlotsForDate(_selectedDate!);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('already booked or requested')) {
        _showAlreadyOnWaitlistSnack();
      } else {
        _showErrorSnack(msg);
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _showWaitingListDialog(_SlotUi slot) async {
    final l10n = context.l10n;
    final join = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPatientSheetBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kPatientGold.withValues(alpha: 0.45)),
        ),
        title: Text(
          l10n.patientJoinWaitingListTitle,
          style: GoogleFonts.urbanist(
            color: kPatientGoldLight,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          l10n.patientJoinWaitingListBody(_selectedDoctorName),
          style: GoogleFonts.urbanist(color: Colors.white70, height: 1.45, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: GoogleFonts.urbanist(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: kPatientGoldDeep,
              foregroundColor: Colors.black,
            ),
            child: Text(l10n.patientJoinList, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (join == true && mounted) {
      await _confirmJoinWaitingList(slot);
    }
  }

  void _onSlotTap(_SlotUi slot) {
    if (_selectedDate == null || _actionBusy) return;

    if (slot.isAvailable) {
      _showConfirmBookingDialog(slot);
    } else if (slot.isBooked) {
      if (slot.isPatientWaiting(widget.patientUserId)) {
        _showAlreadyOnWaitlistSnack();
        return;
      }
      _showWaitingListDialog(slot);
    }
  }

  Widget _buildDoctorSelector() {
    final l10n = context.l10n;
    if (_doctors.isEmpty) return const SizedBox.shrink();

    final validIds = _doctors
        .map((d) => d['userId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final dropdownValue =
        _selectedDoctorId != null && validIds.contains(_selectedDoctorId)
            ? _selectedDoctorId
            : null;

    final menuItems = <DropdownMenuItem<String>>[
      for (final d in _doctors)
        if ((d['userId']?.toString() ?? '').isNotEmpty) ...[
          DropdownMenuItem<String>(
            value: d['userId']!.toString(),
            child: _doctorDropdownTile(d, compact: false),
          ),
        ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: dropdownValue,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          style: patientBodyStyle(color: Colors.white, size: 14),
          iconEnabledColor: kPatientGold,
          decoration: InputDecoration(
            labelText: l10n.patientSelectDoctor,
            labelStyle: TextStyle(color: kPatientGold.withValues(alpha: 0.9)),
            filled: true,
            fillColor: kPatientFieldFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPatientGold),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade700),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPatientGold, width: 1.4),
            ),
          ),
          hint: Text(
            l10n.patientChooseDoctor,
            style: patientBodyStyle(color: Colors.white38, size: 15),
          ),
          selectedItemBuilder: (context) => [
            for (final d in _doctors)
              if ((d['userId']?.toString() ?? '').isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _doctorDropdownTile(d, compact: true),
                ),
          ],
          items: menuItems,
          onChanged: _datesLoading
              ? null
              : (id) {
                  if (id == null || id == _selectedDoctorId) return;
                  Map<String, dynamic>? doc;
                  for (final d in _doctors) {
                    if (d['userId']?.toString() == id) {
                      doc = d;
                      break;
                    }
                  }
                  if (doc == null) return;
                  _onDoctorChanged(id, doc['name']?.toString() ?? 'Doctor');
                },
        ),
        if (_datesLoading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kPatientGold.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.patientLoadingSchedule(_selectedDoctorName),
                  style: patientBodyStyle(color: Colors.white38, size: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _doctorDropdownTile(Map<String, dynamic> doctor, {required bool compact}) {
    final name = _doctorDisplayName(doctor);
    final specialty = doctor['specialty']?.toString().trim() ?? '';

    if (compact) {
      return Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: patientBodyStyle(color: kPatientGoldLight, size: 15).copyWith(fontWeight: FontWeight.w600),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: patientBodyStyle(color: Colors.white, size: 14).copyWith(fontWeight: FontWeight.w600),
        ),
        if (specialty.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            specialty,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: patientBodyStyle(color: Colors.white54, size: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildDateRail() {
    final l10n = context.l10n;
    final dayLabel = DateFormat('EEE');
    final dayNum = DateFormat('d');

    if (_datesLoading) {
      return const SizedBox(
        height: 76,
        child: Center(child: CircularProgressIndicator(color: kPatientGold, strokeWidth: 2)),
      );
    }

    if (_availableDates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Text(
          l10n.patientNoWorkingDays(_selectedDoctorName),
          style: patientBodyStyle(color: Colors.white38, size: 13),
        ),
      );
    }

    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableDates.length,
        itemBuilder: (context, index) {
          final day = _availableDates[index];
          final selected = _selectedDate != null && _sameDay(day, _selectedDate!);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _slotsLoading ? null : () => _onDateSelected(day),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: selected
                        ? kPatientGold.withValues(alpha: 0.22)
                        : kPatientFieldFill.withValues(alpha: 0.85),
                    border: Border.all(
                      color: selected ? kPatientGold : kPatientGold.withValues(alpha: 0.35),
                      width: selected ? 1.6 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: kPatientGold.withValues(alpha: 0.25),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLabel.format(day),
                        style: patientBodyStyle(
                          color: selected ? kPatientGoldLight : Colors.white60,
                          size: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayNum.format(day),
                        style: patientTitleStyle(20).copyWith(
                          color: selected ? kPatientGoldLight : Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotGrid() {
    final l10n = context.l10n;
    if (_slotsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: kPatientGold)),
      );
    }

    if (_onLeave) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            l10n.patientDoctorUnavailable(_selectedDoctorName),
            textAlign: TextAlign.center,
            style: patientBodyStyle(color: Colors.white54, size: 14),
          ),
        ),
      );
    }

    if (!_hasSchedule || _slots.isEmpty) {
      final label = _selectedDate != null
          ? DateFormat('EEE d MMM').format(_selectedDate!)
          : l10n.patientThisDay;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            l10n.patientNoSlotsOnDay(label),
            textAlign: TextAlign.center,
            style: patientBodyStyle(color: Colors.white38, size: 14),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _slots.map((slot) {
        final available = slot.isAvailable;
        return Material(
          color: available
              ? kPatientGold.withValues(alpha: 0.12)
              : const Color(0xFF1A1E1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: available
                  ? kPatientGold.withValues(alpha: 0.75)
                  : Colors.white24,
              width: available ? 1.4 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _actionBusy ? null : () => _onSlotTap(slot),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    slot.displayTime,
                    style: GoogleFonts.urbanist(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: available ? kPatientGoldLight : Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    available
                        ? l10n.patientAvailable
                        : slot.isPatientWaiting(widget.patientUserId)
                            ? l10n.patientOnWaitlist
                            : l10n.patientFullTapToWait,
                    style: GoogleFonts.urbanist(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: available
                          ? kPatientGold.withValues(alpha: 0.9)
                          : slot.isPatientWaiting(widget.patientUserId)
                              ? Colors.amber.shade300
                              : kPatientGold.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPatientGold));
    }
    if (_err != null && _doctors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_err!, textAlign: TextAlign.center, style: patientBodyStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _bootstrap,
                style: FilledButton.styleFrom(backgroundColor: kPatientGoldDeep, foregroundColor: Colors.black),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth > 900 ? 720.0 : c.maxWidth;
        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: kPatientWorkspaceBlack,
            cardColor: const Color(0xFF1A1F1C),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      color: kPatientGold,
                      onRefresh: () async {
                        if (_selectedDoctorId != null) {
                          await _onDoctorChanged(_selectedDoctorId!, _selectedDoctorName);
                        } else {
                          await _bootstrap();
                        }
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          Text(l10n.patientBookWithDoctor, style: patientTitleStyle(18)),
                          const SizedBox(height: 4),
                          Text(
                            l10n.patientBookFlowHint,
                            style: patientBodyStyle(color: Colors.white54, size: 13),
                          ),
                          const SizedBox(height: 16),
                          _buildDoctorSelector(),
                          const SizedBox(height: 16),
                          Text(
                            l10n.patientAvailableDays(_selectedDoctorName),
                            style: patientTitleStyle(14),
                          ),
                          const SizedBox(height: 8),
                          _buildDateRail(),
                          if (_slotsLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                color: kPatientGold,
                                backgroundColor: Color(0xFF2A302C),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(l10n.patientTimeSlots, style: patientTitleStyle(14)),
                          const SizedBox(height: 8),
                          Text(
                            l10n.patientSelectSlotHint(_selectedDoctorName),
                            style: patientBodyStyle(color: Colors.white54, size: 12),
                          ),
                          const SizedBox(height: 12),
                          _buildSlotGrid(),
                        ],
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
  }
}
