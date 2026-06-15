import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../api_config.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../tenant_state.dart';
import '../../../widgets/responsive_layout.dart';
import 'patient_theme.dart';

/// Extract `{ "message": "..." }` from an HTTP error body for SnackBars.
String parseBookingApiMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['message'] != null) {
      return decoded['message'].toString();
    }
  } catch (_) {
    final m = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(body);
    if (m != null) return m.group(1)!;
  }
  final t = body.trim();
  return t;
}

/// Premium dark/gold book flow: specialty → doctor → time slot.
class BookAppointmentDialog extends StatefulWidget {
  const BookAppointmentDialog({
    super.key,
    required this.patientUserId,
    required this.patientName,
    required this.defaultBranch,
    required this.onBook,
    this.rescheduleAppointmentId,
    this.initialDoctorUserId,
    this.initialDoctorName,
    this.initialClinicId,
  });

  final String patientUserId;
  final String patientName;
  final String defaultBranch;
  final String? rescheduleAppointmentId;
  final String? initialDoctorUserId;
  final String? initialDoctorName;
  final String? initialClinicId;
  final Future<void> Function(
    String date,
    String time,
    String doctorName,
    String? clinicId,
    String branch,
    String? doctorUserId,
  ) onBook;

  @override
  State<BookAppointmentDialog> createState() => _BookAppointmentDialogState();
}

class _BookAppointmentDialogState extends State<BookAppointmentDialog> {
  List<dynamic> _specialties = [];
  List<dynamic> _availability = [];
  String? _clinicId;
  String? selectedSpecialty;
  String _branchLabel = '';
  String? selectedDoctorId;
  String _doctorLabel = '';
  late DateTime _date;
  bool _loadingSetup = true;
  bool _loadingAvailability = false;
  String? _err;
  String? selectedTimeSlot;
  String? _bookingApiTime;

  bool get _isReschedule =>
      widget.rescheduleAppointmentId != null && widget.rescheduleAppointmentId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _date = DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
    _clinicId = widget.initialClinicId;
    selectedDoctorId = widget.initialDoctorUserId;
    _doctorLabel = widget.initialDoctorName ?? '';
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loadingSetup = true;
      _err = null;
    });
    try {
      final orgId = TenantState.instance.orgId;
      final clinicsRes =
          await http.get(Uri.parse('$rafeeqApiBase/api/clinics?orgId=$orgId')).timeout(const Duration(seconds: 15));
      if (clinicsRes.statusCode != 200) throw Exception(clinicsRes.body);
      final clinics = jsonDecode(clinicsRes.body) as List<dynamic>;

      final preferred = TenantState.instance.preferredClinicId.trim();
      if (_clinicId == null && preferred.isNotEmpty) {
        _clinicId = preferred;
      } else if (_clinicId == null && clinics.isNotEmpty && clinics.first is Map) {
        _clinicId = (clinics.first as Map)['_id']?.toString();
      }
      for (final raw in clinics) {
        if (raw is! Map) continue;
        if (raw['_id']?.toString() == _clinicId) {
          _branchLabel = raw['name']?.toString() ?? widget.defaultBranch;
          break;
        }
      }
      if (_branchLabel.isEmpty) _branchLabel = widget.defaultBranch;

      if (_clinicId == null) {
        throw Exception('No clinic configured for this organization');
      }

      await _loadSpecialties();
      if (!mounted) return;
      setState(() => _loadingSetup = false);
      if (selectedSpecialty != null) await _loadAvailabilityIfReady();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loadingSetup = false;
      });
    }
  }

  Future<void> _loadSpecialties() async {
    if (_clinicId == null) return;
    final orgId = TenantState.instance.orgId;
    final r = await http
        .get(Uri.parse('$rafeeqApiBase/api/clinics/$_clinicId/specialties?orgId=$orgId'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    if (!mounted) return;
    setState(() {
      _specialties = list;
      if (selectedSpecialty == null && list.isNotEmpty) {
        selectedSpecialty = list.first.toString();
      }
    });
  }

  Future<void> _pickDate() async {
    final first = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
      builder: (c, ch) => Theme(data: patientPickerTheme(context), child: ch ?? const SizedBox.shrink()),
    );
    if (d != null) {
      setState(() {
        _date = d;
        selectedTimeSlot = null;
        _bookingApiTime = null;
      });
      await _loadAvailabilityIfReady();
    }
  }

  Future<void> _showWarningDialog(BuildContext context, String message) {
    final l10n = context.l10n;
    final text = message.trim().isEmpty ? l10n.patientBookingFailed : message;
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPatientWorkspaceBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 52),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l10n.loginOk,
              style: GoogleFonts.urbanist(
                color: Colors.amber,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAvailabilityIfReady() async {
    if (_clinicId == null || selectedSpecialty == null || selectedSpecialty!.isEmpty) return;
    final date = DateFormat('yyyy-MM-dd').format(_date);
    setState(() {
      _loadingAvailability = true;
      _err = null;
    });
    try {
      final orgId = TenantState.instance.orgId;
      final uri = Uri.parse('$rafeeqApiBase/api/clinics/$_clinicId/doctors/availability').replace(
        queryParameters: {
          'date': date,
          'orgId': orgId,
          'specialty': selectedSpecialty!,
        },
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception(r.body);
      final list = jsonDecode(r.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _availability = list;
        _loadingAvailability = false;
        if (selectedDoctorId != null) {
          final stillListed = list.any(
            (e) => e is Map && e['userId']?.toString() == selectedDoctorId,
          );
          if (!stillListed) {
            selectedDoctorId = null;
            _doctorLabel = '';
            selectedTimeSlot = null;
            _bookingApiTime = null;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loadingAvailability = false;
      });
    }
  }

  Future<void> _triggerBooking() async {
    if (_clinicId == null ||
        selectedDoctorId == null ||
        _doctorLabel.isEmpty ||
        selectedTimeSlot == null ||
        (_bookingApiTime ?? '').isEmpty) {
      return;
    }
    final date = DateFormat('yyyy-MM-dd').format(_date);
    final time = _bookingApiTime!;
    final doctorUserId = selectedDoctorId;

    if (_isReschedule) {
      try {
        final res = await http
            .patch(
              Uri.parse('$rafeeqApiBase/api/appointments/${widget.rescheduleAppointmentId}/reschedule'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'patientUserId': widget.patientUserId,
                'date': date,
                'time': time,
                'doctorUserId': doctorUserId,
                'doctorName': _doctorLabel,
              }),
            )
            .timeout(const Duration(seconds: 20));
        if (!mounted) return;
        if (res.statusCode >= 400) {
          await _showWarningDialog(context, parseBookingApiMessage(res.body));
          return;
        }
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.patientRescheduleSuccess)),
        );
        await widget.onBook(date, time, _doctorLabel, _clinicId, _branchLabel, doctorUserId);
      } catch (e) {
        if (!mounted) return;
        await _showWarningDialog(context, parseBookingApiMessage(e.toString()));
      }
      return;
    }

    try {
      final orgId = TenantState.instance.orgId.trim();
      final res = await http
          .post(
            Uri.parse('$rafeeqApiBase/api/appointments/book'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'patientUserId': widget.patientUserId,
              'patientName': widget.patientName,
              'time': time,
              'date': date,
              'doctorName': _doctorLabel,
              'doctorUserId': doctorUserId,
              'branch': _branchLabel,
              if (_clinicId != null) 'clinicId': _clinicId,
              if (orgId.isNotEmpty) 'orgId': orgId,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode >= 400) {
        await _showWarningDialog(context, parseBookingApiMessage(res.body));
        return;
      }
      Navigator.of(context).pop();
      final l10n = context.l10n;
      var successText = l10n.patientAppointmentBookedShort;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['addedToWaitingList'] == true) {
          final msg = decoded['message']?.toString().trim();
          successText = msg != null && msg.isNotEmpty ? msg : l10n.patientSlotFullWaitlistShort;
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successText,
            style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
          ),
          backgroundColor: kPatientSheetBg,
        ),
      );
      await widget.onBook(date, time, _doctorLabel, _clinicId, _branchLabel, doctorUserId);
    } catch (e) {
      if (!mounted) return;
      await _showWarningDialog(context, parseBookingApiMessage(e.toString()));
    }
  }

  List<Map<String, dynamic>> get _filteredDoctors {
    final spec = (selectedSpecialty ?? '').trim().toLowerCase();
    return [
      for (final raw in _availability)
        if (raw is Map<String, dynamic>)
          if (spec.isEmpty || (raw['specialty']?.toString().trim().toLowerCase() ?? '') == spec) raw,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final doctors = _filteredDoctors;

    return AlertDialog(
      backgroundColor: kPatientSheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kPatientGold),
      ),
      title: Text(
        _isReschedule ? l10n.patientSelectNewAppointment : l10n.patientBookAppointment,
        style: GoogleFonts.urbanist(color: kPatientGoldLight, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: RafeeqResponsive.of(context).dialogContentWidth(desktopMax: 440),
        child: _loadingSetup
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: kPatientGold)),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_err != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    DropdownButtonFormField<String>(
                      value: selectedSpecialty,
                      dropdownColor: kPatientFieldFill,
                      style: patientBodyStyle(),
                      decoration: patientInputDec(l10n.patientClinicSpecialty),
                      items: [
                        for (final s in _specialties)
                          DropdownMenuItem(value: s.toString(), child: Text(s.toString())),
                      ],
                      onChanged: _specialties.isEmpty
                          ? null
                          : (v) async {
                              if (v == null) return;
                              setState(() {
                                selectedSpecialty = v;
                                selectedDoctorId = null;
                                _doctorLabel = '';
                                selectedTimeSlot = null;
                                _bookingApiTime = null;
                              });
                              await _loadAvailabilityIfReady();
                            },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, color: kPatientGoldLight),
                      label: Text(DateFormat.yMMMd().format(_date), style: patientBodyStyle(color: kPatientGoldLight)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kPatientGold.withValues(alpha: 0.7)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingAvailability) const LinearProgressIndicator(color: kPatientGold),
                    if (selectedSpecialty == null)
                      Text(
                        l10n.patientSelectSpecialtyFirst,
                        style: patientBodyStyle(color: Colors.white54, size: 13),
                      )
                    else if (doctors.isEmpty && !_loadingAvailability)
                      Text(
                        l10n.patientNoDoctorsForSpecialty,
                        style: patientBodyStyle(color: Colors.white54, size: 13),
                      )
                    else if (doctors.isNotEmpty) ...[
                      Text(l10n.patientChooseDoctorTime, style: patientTitleStyle(14)),
                      const SizedBox(height: 8),
                      for (final raw in doctors) _doctorSlotCard(context, raw),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel, style: patientBodyStyle(color: Colors.white54)),
        ),
        FilledButton(
          onPressed: (selectedDoctorId != null && selectedTimeSlot != null) ? _triggerBooking : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber,
            disabledBackgroundColor: kPatientFieldFill,
            disabledForegroundColor: Colors.white38,
            foregroundColor: kPatientWorkspaceBlack,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            _isReschedule ? l10n.patientConfirmAppointment : l10n.patientBook,
            style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  String _hhmmFromDisplay(String display) {
    final m12 = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false).firstMatch(display.trim());
    if (m12 != null) {
      var h = int.parse(m12.group(1)!);
      final mm = m12.group(2)!;
      final pm = m12.group(3)!.toUpperCase() == 'PM';
      if (pm && h < 12) h += 12;
      if (!pm && h == 12) h = 0;
      return '${h.toString().padLeft(2, '0')}:$mm';
    }
    final m24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(display.trim());
    if (m24 != null) {
      return '${int.parse(m24.group(1)!).toString().padLeft(2, '0')}:${m24.group(2)!}';
    }
    return display;
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

  List<_SlotUi> _parseSlotList(Map<String, dynamic> raw) {
    final slots = raw['availableSlots'] as List<dynamic>? ?? const [];
    final out = <_SlotUi>[];
    for (final entry in slots) {
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        final display = (map['time'] ?? map['label'] ?? '').toString().trim();
        final api = (map['value'] ?? _hhmmFromDisplay(display)).toString().trim();
        if (display.isEmpty && api.isEmpty) continue;
        out.add(_SlotUi(
          displayTime: display.isNotEmpty ? display : _formatSlot12h(api),
          apiTime: api.isNotEmpty ? _hhmmFromDisplay(api) : _hhmmFromDisplay(display),
          isBooked: map['isBooked'] == true,
        ));
      } else {
        final s = entry.toString().trim();
        if (s.isEmpty) continue;
        final api = _hhmmFromDisplay(s);
        out.add(_SlotUi(
          displayTime: RegExp(r'am|pm', caseSensitive: false).hasMatch(s) ? s : _formatSlot12h(api),
          apiTime: api,
          isBooked: false,
        ));
      }
    }
    return out;
  }

  Widget _buildSlotChip({
    required _SlotUi slot,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final booked = slot.isBooked;
    final bg = booked
        ? const Color(0xFF1E2220)
        : selected
            ? Colors.amber
            : const Color(0xFF2A2E2C);
    final borderColor = booked ? Colors.white24 : Colors.amber;
    final textColor = booked
        ? Colors.white38
        : selected
            ? kPatientWorkspaceBlack
            : Colors.white70;

    Widget chip = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Text(
            slot.displayTime,
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );

    if (booked) chip = IgnorePointer(child: chip);
    return chip;
  }

  Widget _doctorSlotCard(BuildContext context, Map<String, dynamic> raw) {
    final l10n = context.l10n;
    final doctorId = raw['userId']?.toString() ?? '';
    final slots = _parseSlotList(raw);
    final onLeave = raw['onLeave'] == true;
    final hasSchedule = raw['hasSchedule'] != false;
    final isSelected = selectedDoctorId == doctorId;
    final showSlotsPanel = isSelected && !onLeave && hasSchedule && slots.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: kPatientFieldFill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              selectedDoctorId = doctorId;
              _doctorLabel = raw['name']?.toString() ?? '';
              selectedTimeSlot = null;
              _bookingApiTime = null;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.amber : kPatientGold.withValues(alpha: 0.4),
                width: isSelected ? 2.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(raw['name']?.toString() ?? '', style: patientBodyStyle()),
                const SizedBox(height: 4),
                Text(
                  raw['specialty']?.toString() ?? '',
                  style: patientBodyStyle(color: Colors.white54, size: 12),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 10),
                  if (onLeave)
                    Text(
                      l10n.patientDoctorOnLeave,
                      style: patientBodyStyle(color: Colors.orangeAccent, size: 12),
                    )
                  else if (!hasSchedule || slots.isEmpty)
                    Text(
                      l10n.patientNoOpenSlots,
                      style: patientBodyStyle(color: Colors.white38, size: 12),
                    )
                  else ...[
                    Text(
                      l10n.patientSelectTime,
                      style: patientBodyStyle(color: kPatientGoldLight, size: 12),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.35,
                      ),
                      itemCount: slots.length,
                      itemBuilder: (context, index) {
                        final slot = slots[index];
                        final slotSelected = selectedTimeSlot == slot.displayTime;
                        return _buildSlotChip(
                          slot: slot,
                          selected: slotSelected,
                          onTap: slot.isBooked
                              ? null
                              : () {
                                  setState(() {
                                    selectedTimeSlot = slot.displayTime;
                                    _bookingApiTime = slot.apiTime;
                                  });
                                },
                        );
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotUi {
  const _SlotUi({
    required this.displayTime,
    required this.apiTime,
    required this.isBooked,
  });

  final String displayTime;
  final String apiTime;
  final bool isBooked;
}

Future<void> showBookAppointmentDialog(
  BuildContext context, {
  required String patientUserId,
  required String patientName,
  required String defaultBranch,
  required Future<void> Function(
    String date,
    String time,
    String doctor,
    String? clinicId,
    String branch,
    String? doctorUserId,
  ) onBook,
  String? rescheduleAppointmentId,
  String? initialDoctorUserId,
  String? initialDoctorName,
  String? initialClinicId,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => BookAppointmentDialog(
      patientUserId: patientUserId,
      patientName: patientName,
      defaultBranch: defaultBranch,
      rescheduleAppointmentId: rescheduleAppointmentId,
      initialDoctorUserId: initialDoctorUserId,
      initialDoctorName: initialDoctorName,
      initialClinicId: initialClinicId,
      onBook: onBook,
    ),
  );
}
