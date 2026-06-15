import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_extensions.dart';
import '../data/patient_portal_api.dart';
import 'patient_theme.dart';

/// Patient view: confirmed bookings + active waiting lists.
class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<PatientAppointmentsScreen> createState() => _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  List<Map<String, dynamic>> _confirmed = [];
  List<Map<String, dynamic>> _waiting = [];
  bool _loading = true;
  String? _err;
  String? _cancellingId;
  String? _leavingWaitlistId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final results = await Future.wait([
        PatientPortalApi.getMyBookings(widget.patientUserId),
        PatientPortalApi.getMyWaitingListEntries(widget.patientUserId),
      ]);
      if (!mounted) return;
      final data = Map<String, dynamic>.from(results[0] as Map);
      final waitingRaw = results[1];
      setState(() {
        _confirmed = [
          for (final e in (data['confirmedBookings'] as List? ?? []))
            if (e is Map) Map<String, dynamic>.from(e),
        ];
        _waiting = waitingRaw is List<Map<String, dynamic>>
            ? waitingRaw
            : [
                if (waitingRaw is List)
                  for (final e in waitingRaw)
                    if (e is Map) Map<String, dynamic>.from(e),
              ];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> appt) async {
    final id = appt['_id']?.toString() ?? '';
    if (id.isEmpty) return;

    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPatientSheetBg,
        title: Text(l10n.patientCancelAppointmentTitle, style: GoogleFonts.urbanist(color: kPatientGoldLight)),
        content: Text(
          l10n.patientCancelAppointmentBody(
            '${appt['date']}',
            '${appt['time']}',
          ),
          style: GoogleFonts.urbanist(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.patientKeep)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: Text(l10n.patientCancelVisit),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _cancellingId = id);
    try {
      final result = await PatientPortalApi.cancelAppointmentByPatient(
        patientUserId: widget.patientUserId,
        appointmentId: id,
      );
      if (!mounted) return;
      final promoted = result['waitlistPromotion'] is Map &&
          (result['waitlistPromotion'] as Map)['promoted'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            promoted ? l10n.patientAppointmentCancelledPromoted : l10n.patientAppointmentCancelled,
            style: GoogleFonts.urbanist(),
          ),
          backgroundColor: promoted ? const Color(0xFF2E7D32) : null,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: const Color(0xFF3A1515)),
      );
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  Future<void> _leaveWaitingList(Map<String, dynamic> entry) async {
    final id = entry['_id']?.toString() ?? '';
    if (id.isEmpty) return;

    final l10n = context.l10n;
    final doctorLabel = entry['doctorName'] != null && entry['doctorName'].toString().isNotEmpty
        ? 'Dr. ${entry['doctorName']}'
        : l10n.doctor;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPatientSheetBg,
        title: Text(l10n.patientCancelRequestTitle, style: GoogleFonts.urbanist(color: kPatientGoldLight)),
        content: Text(
          l10n.patientCancelRequestBody(
            doctorLabel,
            '${entry['date'] ?? entry['watchSlotDate'] ?? entry['preferredDate'] ?? l10n.patientEmDash}',
            '${entry['time'] ?? entry['watchSlotTime'] ?? entry['preferredTime'] ?? l10n.patientEmDash}',
          ),
          style: GoogleFonts.urbanist(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.patientStay)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: Text(l10n.patientCancelRequest),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _leavingWaitlistId = id);
    try {
      await PatientPortalApi.leaveWaitingList(
        patientUserId: widget.patientUserId,
        waitingListEntryId: id,
      );
      if (!mounted) return;
      setState(() {
        _waiting.removeWhere((e) => e['_id']?.toString() == id);
        _leavingWaitlistId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.patientRemovedFromWaitlist, style: GoogleFonts.urbanist()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: const Color(0xFF3A1515)),
      );
      setState(() => _leavingWaitlistId = null);
    }
  }

  Widget _badge({required String label, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _confirmedCard(BuildContext context, Map<String, dynamic> appt) {
    final l10n = context.l10n;
    final id = appt['_id']?.toString() ?? '';
    final fromWaitlist = appt['promotedFromWaitlist'] == true;
    final forceAccepted = appt['isForceAccepted'] == true;
    final canCancel = appt['canCancel'] != false;
    final cancelling = _cancellingId == id;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF1A1F1C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: kPatientGold.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appt['doctorName']?.toString().isNotEmpty == true
                        ? 'Dr. ${appt['doctorName']}'
                        : l10n.patientAppointmentLabel,
                    style: patientBodyStyle(color: Colors.white, size: 16).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (fromWaitlist)
                  _badge(
                    label: l10n.patientConfirmedFromWaitlist,
                    bg: const Color(0xFF1B3D24),
                    fg: const Color(0xFF81C784),
                  )
                else if (forceAccepted)
                  _badge(
                    label: l10n.patientDoctorApproved,
                    bg: kPatientGold.withValues(alpha: 0.15),
                    fg: kPatientGoldLight,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${appt['date'] ?? '—'} · ${appt['time'] ?? '—'}',
              style: patientBodyStyle(color: Colors.white70, size: 14),
            ),
            if (canCancel) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: cancelling
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                      )
                    : TextButton.icon(
                        onPressed: () => _cancelBooking(appt),
                        icon: const Icon(Icons.event_busy, color: Colors.redAccent, size: 20),
                        label: Text(
                          l10n.patientCancelAppointment,
                          style: GoogleFonts.urbanist(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _waitingCard(BuildContext context, Map<String, dynamic> entry) {
    final l10n = context.l10n;
    final id = entry['_id']?.toString() ?? '';
    final leaving = _leavingWaitlistId == id;
    final doctorName = entry['doctorName']?.toString().trim() ?? '';
    final clinicName = entry['clinicName']?.toString().trim() ?? '';
    final date = entry['date']?.toString() ??
        entry['watchSlotDate']?.toString() ??
        entry['preferredDate']?.toString() ??
        '—';
    final time = entry['time']?.toString() ??
        entry['watchSlotTime']?.toString() ??
        entry['preferredTime']?.toString() ??
        '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF1A1F1C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hourglass_bottom, color: kPatientGold.withValues(alpha: 0.8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (doctorName.isNotEmpty)
                        Text(
                          doctorName.startsWith('Dr.') ? doctorName : 'Dr. $doctorName',
                          style: patientBodyStyle(color: Colors.white, size: 15).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (clinicName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          clinicName,
                          style: patientBodyStyle(color: kPatientGoldLight, size: 13),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '$date · $time',
                        style: patientBodyStyle(color: Colors.white, size: 15).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.patientOnWaitingListHint,
                        style: patientBodyStyle(color: Colors.white54, size: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: leaving ? null : () => _leaveWaitingList(entry),
                icon: leaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.cancel_outlined, color: Colors.orange.shade200, size: 20),
                label: Text(
                  l10n.patientLeaveWaitingList,
                  style: GoogleFonts.urbanist(
                    color: Colors.orange.shade200,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: kPatientWorkspaceBlack),
      child: Scaffold(
        backgroundColor: kPatientWorkspaceBlack,
        appBar: AppBar(
          backgroundColor: kPatientWorkspaceBlack,
          foregroundColor: kPatientGoldLight,
          title: Text(l10n.patientMyBookings, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: l10n.refresh),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kPatientGold))
            : _err != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_err!, textAlign: TextAlign.center, style: patientBodyStyle(color: Colors.white70)),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: _load, child: Text(l10n.retry)),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: kPatientGold,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        Text(l10n.patientConfirmedBookings, style: patientTitleStyle(16)),
                        const SizedBox(height: 8),
                        if (_confirmed.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              l10n.patientNoUpcomingVisits,
                              style: patientBodyStyle(color: Colors.white38, size: 13),
                            ),
                          )
                        else
                          ..._confirmed.map((a) => _confirmedCard(context, a)),
                        const SizedBox(height: 20),
                        Text(l10n.patientWaitingLists, style: patientTitleStyle(16)),
                        const SizedBox(height: 8),
                        if (_waiting.isEmpty)
                          Text(
                            l10n.patientNotOnWaitingLists,
                            style: patientBodyStyle(color: Colors.white38, size: 13),
                          )
                        else
                          ..._waiting.map((e) => _waitingCard(context, e)),
                      ],
                    ),
                  ),
      ),
    );
  }
}
