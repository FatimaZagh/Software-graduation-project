import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../utils/allergy_display.dart';
import '../../../utils/patient_user_id_utils.dart';
import '../../billing/models/doctor_billing_profile.dart';
import '../../billing/presentation/session_billing_dialog.dart';
import 'doctor_prescribe_screen.dart';
import '../data/doctor_portal_api.dart';
import '../data/doctor_workspace_api.dart';
import 'doctor_adr_detail_screen.dart';
import 'doctor_chat_room_screen.dart';
import 'patient_details_screen.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kGlass = Color(0xE6101A18);

/// Material-backed row — ListTile ink requires a [Material] ancestor, not [ColoredBox].
Widget _glassMaterialListTile({
  required Widget title,
  Widget? subtitle,
  Widget? leading,
  Widget? trailing,
  VoidCallback? onTap,
  bool dense = false,
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 8),
}) {
  return Padding(
    padding: margin,
    child: Material(
      color: _kGlass,
      elevation: 0,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: dense,
        onTap: onTap,
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    ),
  );
}

const _availabilityStates = ['Available', 'Busy', 'In Surgery', 'Offline'];
const _severities = ['Mild', 'Moderate', 'Severe', 'Critical'];
const _labTypes = ['Blood', 'Urine', 'Culture', 'Biochemistry', 'Other'];
const _modalities = ['X-Ray', 'MRI', 'CT', 'Ultrasound'];

/// Demo-only in-memory session payments (presentation mode — no backend billing).
final Map<String, List<Map<String, dynamic>>> mockSessionPaymentsByPatient = {};

List<Map<String, dynamic>> mockSessionPaymentsFor(String patientKey) =>
    List.unmodifiable(mockSessionPaymentsByPatient[patientKey] ?? const []);

Future<bool> _runSessionBilling({
  required BuildContext context,
  required DoctorWorkspaceApi api,
  required String patientUserId,
  required String patientName,
  String? appointmentId,
}) async {
  const mockFee = 100.0;
  const feeProfile = DoctorBillingProfile(consultationFee: mockFee);

  if (!context.mounted) return false;
  final choice = await showSessionBillingDialog(
    context,
    defaultFee: mockFee,
    patientName: patientName,
    displayedFeeLabel: feeProfile.displayedFeeLabel,
  );
  if (choice == null) return false;
  if (!context.mounted) return false;

  final storeKey = mongoIdFromDynamic(patientUserId).isNotEmpty
      ? mongoIdFromDynamic(patientUserId)
      : patientUserId.trim();

  final mockNewPayment = {
    'id': 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    'amount': mockFee,
    'type': 'Consultation Fee',
    'status': 'Paid',
    'date': 'Just Now',
    if (appointmentId != null && appointmentId.isNotEmpty) 'appointmentId': appointmentId,
  };
  mockSessionPaymentsByPatient.putIfAbsent(storeKey, () => []);
  mockSessionPaymentsByPatient[storeKey]!.insert(0, mockNewPayment);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFFD4AF37)),
          SizedBox(width: 12),
          Text(
            'Session fee (100 ILS) deducted successfully!',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      backgroundColor: Color(0xFF0D1A17),
      duration: Duration(seconds: 2),
    ),
  );

  // Presentation demo — backend billing disabled for graduation demo.
  // final billing = BillingApi(doctorUserId: api.doctorUserId);
  // await billing.deductSession(
  //   patientUserId: resolvedPatientId,
  //   amount: choice.amount,
  //   appointmentId: appointmentId,
  // );

  return true;
}

InputDecoration _dec(String label, {bool readOnly = false}) => InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.urbanist(color: _kGold.withValues(alpha: readOnly ? 0.5 : 0.9)),
      filled: readOnly,
      fillColor: readOnly ? const Color(0xFF141412) : null,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _kGold.withValues(alpha: readOnly ? 0.25 : 0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _kGold, width: readOnly ? 1 : 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _kGold.withValues(alpha: 0.25)),
      ),
    );

TextStyle _fieldTextStyle({bool readOnly = false}) =>
    TextStyle(color: readOnly ? Colors.white54 : Colors.white);

/// Tab 1 — KPIs + feature grid + live queue + availability
class DoctorHomeTab extends StatefulWidget {
  const DoctorHomeTab({super.key, required this.api, this.onFeatureSelected});

  final DoctorWorkspaceApi api;
  final void Function(String featureKey)? onFeatureSelected;

  @override
  State<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends State<DoctorHomeTab> {
  Map<String, dynamic> _stats = {};
  List<dynamic> _queue = [];
  List<Map<String, dynamic>> _adrReports = [];
  String _availability = 'Available';
  bool _loading = true;

  /// Newest submitted ADR reports first (matches backend `createdAt: -1`).
  static void _sortAdrInPlace(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final tb = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final ta = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.dashboardStats(),
        widget.api.todayQueue(),
        widget.api.adverseReports(),
      ]);
      if (!mounted) return;
      final rawAdr = results[2] as List<dynamic>;
      final adr = <Map<String, dynamic>>[
        for (final e in rawAdr)
          if (e is Map) Map<String, dynamic>.from(e as Map),
      ];
      _sortAdrInPlace(adr);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _queue = results[1] as List<dynamic>;
        _adrReports = adr;
        _availability = _stats['availabilityStatus']?.toString() ?? 'Available';
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String _reportId(Map<String, dynamic> r) => r['_id']?.toString() ?? r['id']?.toString() ?? '';

  String _adrDoctorStatus(Map<String, dynamic> r) {
    final da = r['doctorAction'];
    if (da is Map) return da['status']?.toString() ?? 'Pending';
    return 'Pending';
  }

  bool _adrIsUrgent(Map<String, dynamic> r) {
    final status = _adrDoctorStatus(r);
    return status == 'Pending' || status == 'Active';
  }

  void _updateAdrStatusLocal(String reportId, String status) {
    final idx = _adrReports.indexWhere((r) => _reportId(r) == reportId);
    if (idx < 0) return;
    final updated = Map<String, dynamic>.from(_adrReports[idx]);
    final da = Map<String, dynamic>.from(updated['doctorAction'] as Map? ?? {});
    da['status'] = status;
    updated['doctorAction'] = da;
    _adrReports[idx] = updated;
  }

  Future<void> _openAdrDetail(Map<String, dynamic> r) async {
    final id = _reportId(r);
    if (id.isEmpty) return;

    final wasPending = _adrIsUrgent(r);
    if (wasPending) {
      try {
        await widget.api.acknowledgeADRAlert(id);
        if (!mounted) return;
        setState(() => _updateAdrStatusLocal(id, 'Reviewed'));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        return;
      }
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DoctorAdrDetailScreen(
          api: widget.api,
          initialReport: Map<String, dynamic>.from(_adrReports.firstWhere(
            (item) => _reportId(item) == id,
            orElse: () => r,
          )),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _proposeSuspension(Map<String, dynamic> r) async {
    final id = _reportId(r);
    if (id.isEmpty) return;
    try {
      await widget.api.proposeAdverseMedicationSuspension(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  static const _featureItems = <({IconData icon, String key})>[
    (icon: Icons.event_note_outlined, key: 'appointments'),
    (icon: Icons.hourglass_top_outlined, key: 'waiting_list'),
    (icon: Icons.calendar_month_outlined, key: 'my_schedule'),
    (icon: Icons.folder_shared_outlined, key: 'patient_records'),
    (icon: Icons.medication_outlined, key: 'e_prescription'),
    (icon: Icons.biotech_outlined, key: 'order_lab'),
    (icon: Icons.radar_outlined, key: 'order_imaging'),
    (icon: Icons.insights_outlined, key: 'clinic_analytics'),
  ];

  Widget _featureCard({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: _kGlass,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kGold.withValues(alpha: 0.55)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _kGoldLight, size: 28),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _featureLabel(String key, S l10n) {
    switch (key) {
      case 'appointments':
        return l10n.doctorGridAppointments;
      case 'waiting_list':
        return l10n.doctorGridWaitingList;
      case 'my_schedule':
        return l10n.doctorGridMySchedule;
      case 'patient_records':
        return l10n.doctorGridPatientRecords;
      case 'e_prescription':
        return l10n.doctorGridEPrescription;
      case 'order_lab':
        return l10n.doctorGridOrderLab;
      case 'order_imaging':
        return l10n.doctorGridOrderImaging;
      case 'clinic_analytics':
        return l10n.doctorGridClinicAnalytics;
      default:
        return key;
    }
  }

  Widget _featureGrid(S l10n) {
    final crossAxisCount = MediaQuery.sizeOf(context).width >= 900 ? 4 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: _featureItems.length,
      itemBuilder: (_, i) {
        final item = _featureItems[i];
        return _featureCard(
          icon: item.icon,
          label: _featureLabel(item.key, l10n),
          onTap: () => widget.onFeatureSelected?.call(item.key),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kGold));
    return RefreshIndicator(
      color: _kGold,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.doctorGridClinicalOverview,
            style: GoogleFonts.urbanist(color: _kGold, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpi(l10n.doctorGridActivePatients, '${_stats['totalPatients'] ?? 0}'),
              _kpi(l10n.doctorGridCompletedVisits, '${_stats['completedVisits'] ?? 0}'),
              _kpi(l10n.doctorGridDailyCases, '${_stats['dailyCases'] ?? 0}'),
              _kpi(l10n.doctorGridFollowUps, '${_stats['followUpAppointments'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            l10n.doctorGridQuickActions,
            style: GoogleFonts.urbanist(color: _kGold, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _featureGrid(l10n),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(l10n.doctorGridAvailability, style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _availabilityStates.contains(_availability) ? _availability : 'Available',
                  dropdownColor: const Color(0xFF1A1A18),
                  style: GoogleFonts.urbanist(color: Colors.white),
                  decoration: _dec(l10n.status),
                  items: _availabilityStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    await widget.api.setAvailability(v);
                    setState(() => _availability = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(l10n.doctorGridTodaysQueue, style: GoogleFonts.urbanist(color: _kGold, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_queue.isEmpty)
            Text(l10n.doctorGridNoPatientsToday, style: GoogleFonts.urbanist(color: Colors.white54))
          else
            ..._queue.asMap().entries.map((e) {
              final m = e.value as Map<String, dynamic>;
              return Card(
                color: _kGlass,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _kGold.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _kGold.withValues(alpha: 0.2),
                    child: Text('${e.key + 1}', style: const TextStyle(color: _kGold)),
                  ),
                  title: Text(m['patientName']?.toString() ?? 'Patient', style: const TextStyle(color: Colors.white)),
                  subtitle: Text('${m['time']} · ${m['status']}', style: const TextStyle(color: Colors.white54)),
                ),
              );
            }),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.report_problem_outlined, color: _kGold.withValues(alpha: 0.9), size: 22),
              const SizedBox(width: 8),
              Text(l10n.doctorGridAdrReports, style: GoogleFonts.urbanist(color: _kGold, fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          if (_adrReports.isEmpty)
            Text(l10n.doctorGridNoAdrReports, style: GoogleFonts.urbanist(color: Colors.white54))
          else
            ..._adrReports.map((r) {
              final status = _adrDoctorStatus(r);
              final isUrgent = _adrIsUrgent(r);
              final isReviewed = status == 'Reviewed';
              final med = r['medicationName']?.toString() ?? l10n.doctorMedicationFallback;
              final problem = r['problemType']?.toString() ?? '';
              final sev = r['severity']?.toString() ?? '';
              final patientHint = r['patientId']?.toString() ?? '';
              final shortPatient = patientHint.length > 8 ? '…${patientHint.substring(patientHint.length - 6)}' : patientHint;
              final canSuspend = r['proposeSuspensionAvailable'] == true;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isUrgent ? const Color(0xFF3A1212) : _kGlass,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUrgent ? Colors.redAccent.shade200 : _kGold.withValues(alpha: 0.45),
                    width: isUrgent ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        onTap: () => _openAdrDetail(r),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isUrgent)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    l10n.doctorAdrUrgent,
                                    style: GoogleFonts.urbanist(
                                      color: Colors.redAccent.shade100,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              else if (isReviewed)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    l10n.doctorAdrReviewed,
                                    style: GoogleFonts.urbanist(
                                      color: _kGoldLight.withValues(alpha: 0.75),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              Text(med, style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                '$problem · $sev · Status: $status',
                                style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 13),
                              ),
                              if (shortPatient.isNotEmpty)
                                Text(l10n.doctorAdrPatientRef(shortPatient), style: GoogleFonts.urbanist(color: Colors.white38, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                l10n.doctorAdrTapDetail,
                                style: GoogleFonts.urbanist(color: _kGold.withValues(alpha: 0.55), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (canSuspend)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _proposeSuspension(r),
                            child: Text(
                              l10n.doctorProposeSuspension,
                              style: GoogleFonts.urbanist(color: Colors.red.shade200, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _kpi(String title, String value) {
    return SizedBox(
      width: 160,
      child: Card(
        color: _kGlass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _kGold.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              Text(value, style: GoogleFonts.urbanist(color: _kGold, fontSize: 24, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the patient clinical examination bottom sheet (diagnosis + Rx).
Future<void> showPatientDiagnosisSheet(
  BuildContext context, {
  required DoctorWorkspaceApi api,
  required String patientUserId,
  required String patientName,
  required String specialty,
  String? appointmentId,
  String? visitStatus,
  bool closeOnClinicalSave = false,
}) async {
  if (!context.mounted) return;

  final trimmedId = mongoIdFromDynamic(patientUserId);
  if (trimmedId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.doctorPatientMissingExam)),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PatientEmrSheet(
      api: api,
      patientUserId: trimmedId,
      patientName: patientName.trim().isEmpty ? 'Patient' : patientName.trim(),
      specialty: specialty,
      appointmentId: appointmentId,
      visitStatus: visitStatus,
      closeOnClinicalSave: closeOnClinicalSave,
    ),
  );
}

/// Tab 2 — appointments timeline
class DoctorAppointmentsTab extends StatefulWidget {
  const DoctorAppointmentsTab({super.key, required this.api, this.specialty = 'General Practice'});
  final DoctorWorkspaceApi api;
  final String specialty;

  @override
  State<DoctorAppointmentsTab> createState() => _DoctorAppointmentsTabState();
}

class _DoctorAppointmentsTabState extends State<DoctorAppointmentsTab> with SingleTickerProviderStateMixin {
  List<dynamic> _list = [];
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  static bool _isCancelled(Map<String, dynamic> m) {
    final v = m['status']?.toString() ?? '';
    final b = m['bookingStatus']?.toString() ?? '';
    return v == 'cancelled_by_doctor' ||
        v == 'cancelled_by_patient' ||
        b == 'cancelled_by_doctor' ||
        b == 'cancelled_by_patient' ||
        v == 'Cancelled';
  }

  List<Map<String, dynamic>> get _active {
    return [
      for (final raw in _list)
        if (raw is Map && !_isCancelled(Map<String, dynamic>.from(raw)))
          Map<String, dynamic>.from(raw),
    ];
  }

  List<Map<String, dynamic>> get _cancelled {
    return [
      for (final raw in _list)
        if (raw is Map && _isCancelled(Map<String, dynamic>.from(raw)))
          Map<String, dynamic>.from(raw),
    ];
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.appointments();
      if (mounted) setState(() { _list = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _appointmentList(List<Map<String, dynamic>> items, {required bool readOnly}) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          readOnly ? context.l10n.doctorNoCancelledAppointments : context.l10n.doctorNoActiveAppointments,
          style: GoogleFonts.urbanist(color: Colors.white54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) => _AppointmentCard(
        api: widget.api,
        raw: items[i],
        readOnly: readOnly,
        specialty: widget.specialty,
        onChanged: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kGold));
    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          labelColor: _kGold,
          unselectedLabelColor: Colors.white54,
          indicatorColor: _kGold,
          tabs: [
            Tab(text: context.l10n.doctorTabActive),
            Tab(text: context.l10n.doctorTabCancelled),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            color: _kGold,
            onRefresh: _load,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _appointmentList(_active, readOnly: false),
                _appointmentList(_cancelled, readOnly: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AppointmentCard extends StatefulWidget {
  const _AppointmentCard({
    required this.api,
    required this.raw,
    required this.onChanged,
    this.readOnly = false,
    this.specialty = 'General Practice',
  });
  final DoctorWorkspaceApi api;
  final Map<String, dynamic> raw;
  final VoidCallback onChanged;
  final bool readOnly;
  final String specialty;

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  late String _bookingStatus;
  late String _visitStatus;
  static const _cancelReasons = [
    'Emergency',
    'Sick Leave',
    'Surgery',
    'Equipment Issue',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _syncFromRaw();
  }

  @override
  void didUpdateWidget(covariant _AppointmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raw['_id'] != widget.raw['_id'] ||
        oldWidget.raw['bookingStatus'] != widget.raw['bookingStatus'] ||
        oldWidget.raw['status'] != widget.raw['status']) {
      _syncFromRaw();
    }
  }

  void _syncFromRaw() {
    _bookingStatus = widget.raw['bookingStatus']?.toString() ?? '';
    _visitStatus = widget.raw['status']?.toString() ?? '';
  }

  String get _appointmentId => widget.raw['_id']?.toString() ?? '';

  String get _patientUserId => resolvePatientUserId(Map<String, dynamic>.from(widget.raw));

  String get _patientName => widget.raw['patientName']?.toString() ?? 'Patient';

  bool get _isVisitInProgress => _visitStatus == 'In Progress';

  bool get _isVisitCompleted => _visitStatus == 'Completed';

  bool get _isBookingPending => _bookingStatus == 'Pending';

  bool get _isBookingAccepted =>
      _bookingStatus == 'Accepted' && !_isVisitInProgress && !_isVisitCompleted;

  Future<void> _openExaminationSheet({bool closeOnSave = false}) async {
    if (_patientUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient ID missing on this appointment — cannot open examination.')),
      );
      return;
    }
    await showPatientDiagnosisSheet(
      context,
      api: widget.api,
      patientUserId: _patientUserId,
      patientName: _patientName,
      specialty: widget.specialty,
      appointmentId: _appointmentId,
      visitStatus: _visitStatus,
      closeOnClinicalSave: closeOnSave,
    );
  }

  Future<void> _acceptAppointment() async {
    if (_appointmentId.isEmpty) return;
    setState(() => _bookingStatus = 'Accepted');
    try {
      await widget.api.updateAppointmentStatus(_appointmentId, {'bookingStatus': 'Accepted'});
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _bookingStatus = widget.raw['bookingStatus']?.toString() ?? 'Pending');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _postponeAppointment() async {
    if (_appointmentId.isEmpty) return;
    try {
      await widget.api.postponeAppointment(_appointmentId);
      widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _startVisit() async {
    if (_appointmentId.isEmpty) return;
    if (_patientUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient ID missing on this appointment — cannot start examination.')),
      );
      return;
    }

    setState(() => _visitStatus = 'In Progress');
    try {
      await widget.api.updateAppointmentStatus(_appointmentId, {'visitStatus': 'In Progress'});
      widget.onChanged();
      if (!mounted) return;
      await _openExaminationSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() => _visitStatus = widget.raw['status']?.toString() ?? '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _terminateVisit() async {
    if (_appointmentId.isEmpty) return;
    final billed = await _runSessionBilling(
      context: context,
      api: widget.api,
      patientUserId: _patientUserId,
      patientName: _patientName,
      appointmentId: _appointmentId,
    );
    if (!billed || !mounted) return;

    setState(() => _visitStatus = 'Completed');
    try {
      await widget.api.updateAppointmentStatus(_appointmentId, {
        'visitStatus': 'Completed',
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _visitStatus = widget.raw['status']?.toString() ?? '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _buildGoldButton({required String text, required VoidCallback? onPressed}) {
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
      onPressed: onPressed,
      child: Text(text),
    );
  }

  Widget _buildOutlineButton({required String text, required VoidCallback? onPressed}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(foregroundColor: _kGoldLight, side: BorderSide(color: _kGold.withValues(alpha: 0.55))),
      onPressed: onPressed,
      child: Text(text),
    );
  }

  Widget _buildRedOutlineButton({required String text, required VoidCallback? onPressed}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
      onPressed: onPressed,
      child: Text(text),
    );
  }

  Widget _buildPurpleButton({required String text, required VoidCallback? onPressed}) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF7E57C2),
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }

  Widget _buildDarkButton({required String text, required VoidCallback? onPressed}) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2A2A28),
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      onPressed: onPressed,
      child: Text(text),
    );
  }

  Widget _buildActionButtons() {
    if (widget.readOnly) return const SizedBox.shrink();

    if (_isBookingPending) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildGoldButton(
            text: 'Accept',
            onPressed: _appointmentId.isEmpty ? null : _acceptAppointment,
          ),
          _buildOutlineButton(
            text: 'Postpone',
            onPressed: _appointmentId.isEmpty ? null : _postponeAppointment,
          ),
          _buildRedOutlineButton(
            text: 'Cancel Appointment',
            onPressed: _appointmentId.isEmpty ? null : () => _showCancelDialog(_appointmentId),
          ),
        ],
      );
    }

    if (_isBookingAccepted) {
      return Wrap(
        spacing: 8,
        children: [
          _buildPurpleButton(
            text: 'Start visit',
            onPressed: _appointmentId.isEmpty ? null : _startVisit,
          ),
        ],
      );
    }

    if (_isVisitInProgress) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildGoldButton(
            text: 'Open Examination',
            onPressed: _appointmentId.isEmpty ? null : _openExaminationSheet,
          ),
          _buildDarkButton(
            text: 'Terminate',
            onPressed: _appointmentId.isEmpty ? null : _terminateVisit,
          ),
        ],
      );
    }

    if (_isVisitCompleted) {
      return Wrap(
        spacing: 8,
        children: [
          _buildOutlineButton(
            text: 'View Medical Record',
            onPressed: _appointmentId.isEmpty ? null : _openExaminationSheet,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _showCancelDialog(String appointmentId) async {
    String selectedReason = _cancelReasons.first;
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1510),
          title: Text('Cancel Appointment', style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Select Reason', style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  dropdownColor: _kGlass,
                  style: GoogleFonts.urbanist(color: Colors.white),
                  decoration: _dec('Reason'),
                  items: [
                    for (final r in _cancelReasons)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setDialogState(() => selectedReason = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  style: GoogleFonts.urbanist(color: Colors.white),
                  maxLines: 3,
                  decoration: _dec('Notes (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm cancel'),
            ),
          ],
        ),
      ),
    );
    final doctorNotes = notesCtrl.text.trim();
    notesCtrl.dispose();
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.cancelAppointmentByDoctor(
        appointmentId: appointmentId,
        reason: selectedReason,
        notes: doctorNotes.isEmpty ? null : doctorNotes,
      );
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment cancelled — patient notified')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _bookingStatus;
    final visit = _visitStatus;
    final isCancelled = widget.readOnly ||
        visit == 'cancelled_by_doctor' ||
        visit == 'cancelled_by_patient' ||
        booking == 'cancelled_by_doctor' ||
        booking == 'cancelled_by_patient' ||
        visit == 'Cancelled';
    return Card(
      color: _kGlass,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCancelled ? Colors.redAccent.withValues(alpha: 0.5) : _kGold.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.raw['patientName']?.toString() ?? '',
                    style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                if (isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.7)),
                    ),
                    child: Text(
                      'Cancelled',
                      style: GoogleFonts.urbanist(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${widget.raw['date']} ${widget.raw['time']}', style: const TextStyle(color: Colors.white54)),
            if (!isCancelled) ...[
              const SizedBox(height: 4),
              Text('Booking: $booking · Visit: $visit', style: TextStyle(color: _kGold.withValues(alpha: 0.85), fontSize: 12)),
              const SizedBox(height: 8),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tab 3 — EMR + clinical actions
class DoctorPatientsTab extends StatefulWidget {
  const DoctorPatientsTab({super.key, required this.api, required this.specialty});
  final DoctorWorkspaceApi api;
  final String specialty;

  @override
  State<DoctorPatientsTab> createState() => _DoctorPatientsTabState();
}

class _DoctorPatientsTabState extends State<DoctorPatientsTab> {
  final _search = TextEditingController();
  List<dynamic> _patients = [];
  bool _loading = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load([String? q]) async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.patients(q: q);
      if (mounted) setState(() { _patients = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _openPatientDetails(Map<String, dynamic> row) {
    final patientId = resolvePatientUserId(row);
    if (patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient ID missing — cannot open medical record.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => PatientDetailsScreen(
          api: widget.api,
          patientId: patientId,
          patientName: row['name']?.toString() ?? 'Patient',
          onNewExamination: (sheetContext) => showPatientDiagnosisSheet(
            sheetContext,
            api: widget.api,
            patientUserId: patientId,
            patientName: row['name']?.toString() ?? 'Patient',
            specialty: widget.specialty,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            style: GoogleFonts.urbanist(color: Colors.white),
            decoration: _dec('Search patients').copyWith(
              suffixIcon: IconButton(icon: const Icon(Icons.search, color: _kGold), onPressed: () => _load(_search.text.trim())),
            ),
            onSubmitted: _load,
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kGold))
              : ListView.builder(
                  itemCount: _patients.length,
                  itemBuilder: (_, i) {
                    final m = Map<String, dynamic>.from(_patients[i] as Map);
                    return _glassMaterialListTile(
                      title: Text(m['name']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(m['email']?.toString() ?? '', style: const TextStyle(color: Colors.white54)),
                      trailing: const Icon(Icons.chevron_right, color: _kGold),
                      onTap: () => _openPatientDetails(m),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PatientEmrSheet extends StatefulWidget {
  const _PatientEmrSheet({
    required this.api,
    required this.patientUserId,
    required this.patientName,
    required this.specialty,
    this.appointmentId,
    this.visitStatus,
    this.closeOnClinicalSave = false,
  });
  final DoctorWorkspaceApi api;
  final String patientUserId;
  final String patientName;
  final String specialty;
  final String? appointmentId;
  final String? visitStatus;
  final bool closeOnClinicalSave;

  @override
  State<_PatientEmrSheet> createState() => _PatientEmrSheetState();
}

class _PatientEmrSheetState extends State<_PatientEmrSheet> {
  Map<String, dynamic>? _emr;
  bool _loading = true;
  bool _submitting = false;
  bool _isOrderingLab = false;
  bool _isOrderingImaging = false;

  bool get _isSessionLocked => widget.visitStatus == 'Completed';

  bool get _isActiveAppointmentSession =>
      widget.appointmentId != null &&
      widget.appointmentId!.isNotEmpty &&
      widget.visitStatus == 'In Progress';

  final _condition = TextEditingController();
  final _symptoms = TextEditingController();
  String _severity = 'Moderate';
  final _treatment = TextEditingController();
  final _medName = TextEditingController();
  final _dosage = TextEditingController();
  final _frequency = TextEditingController();
  final _durationQty = TextEditingController();
  String _durationUnit = 'Days';
  String? _durationQtyError;
  final _instructions = TextEditingController();
  String _labType = 'Blood';
  final _labTest = TextEditingController();
  String _modality = 'X-Ray';
  final _radStudy = TextEditingController();

  @override
  void dispose() {
    _condition.dispose();
    _symptoms.dispose();
    _treatment.dispose();
    _medName.dispose();
    _dosage.dispose();
    _frequency.dispose();
    _durationQty.dispose();
    _instructions.dispose();
    _labTest.dispose();
    _radStudy.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final emr = await widget.api.patientEmr(widget.patientUserId);
      if (!mounted) return;
      setState(() {
        _emr = emr;
        _loading = false;
      });
      _hydrateAppointmentSession(emr);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _hydrateAppointmentSession(Map<String, dynamic> emr) {
    final apptId = widget.appointmentId?.trim() ?? '';
    if (apptId.isEmpty) return;

    final diagnoses = emr['diagnoses'] as List<dynamic>? ?? [];
    for (final raw in diagnoses) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      if (map['appointmentId']?.toString() != apptId) continue;
      _condition.text = map['condition']?.toString() ?? '';
      final symptoms = map['symptoms'];
      if (symptoms is List) {
        _symptoms.text = symptoms.map((s) => s.toString()).where((s) => s.isNotEmpty).join(', ');
      }
      final severity = map['severity']?.toString();
      if (severity != null && _severities.contains(severity)) {
        _severity = severity;
      }
      _treatment.text = map['treatmentPlan']?.toString() ?? '';
      break;
    }

    final prescriptions = emr['prescriptions'] as List<dynamic>? ?? [];
    for (final raw in prescriptions) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      if (map['appointmentId']?.toString() != apptId) continue;
      _medName.text = map['medicationName']?.toString() ?? '';
      _dosage.text = map['dosage']?.toString() ?? '';
      _frequency.text = map['frequency']?.toString() ?? '';
      _instructions.text = map['instructions']?.toString() ?? '';
      final parsed = parseMedicationDurationString(map['duration']?.toString());
      if (parsed != null) {
        _durationQty.text = parsed.value;
        _durationUnit = parsed.unit;
      }
      break;
    }

    if (mounted) setState(() {});
  }

  void _resetFormControllers() {
    _condition.clear();
    _symptoms.clear();
    _severity = 'Moderate';
    _treatment.clear();
    _medName.clear();
    _dosage.clear();
    _frequency.clear();
    _durationQty.clear();
    _durationUnit = 'Days';
    _durationQtyError = null;
    _instructions.clear();
    _labType = 'Blood';
    _labTest.clear();
    _modality = 'X-Ray';
    _radStudy.clear();
  }

  void _closeSheetAfterSubmit() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  void initState() {
    super.initState();
    _resetFormControllers();
    _load();
  }

  @override
  void didUpdateWidget(covariant _PatientEmrSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientUserId != widget.patientUserId ||
        oldWidget.appointmentId != widget.appointmentId ||
        oldWidget.visitStatus != widget.visitStatus) {
      _resetFormControllers();
      _load();
    }
  }

  Future<bool> _safetyGate() async {
    final check = await widget.api.safetyCheck(
      patientUserId: widget.patientUserId,
      medicationName: _medName.text.trim(),
      dosage: _dosage.text.trim(),
    );
    if (check['highRisk'] != true) return true;
    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1510),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _kGold, size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text('WARNING', style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w800))),
          ],
        ),
        content: Text(
          '🚨 WARNING: High Risk Patient Drug Allergy / Overdose detected!\n\n${(check['warnings'] as List?)?.map((w) => (w as Map)['message']).join('\n') ?? ''}',
          style: GoogleFonts.urbanist(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed anyway'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  String _apiErrorMessage(Object e) {
    final s = e.toString();
    try {
      final start = s.indexOf('{');
      if (start >= 0) {
        final map = jsonDecode(s.substring(start)) as Map;
        final msg = map['message']?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return s.replaceFirst('Exception: ', '');
  }

  void _showDiagnosticSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.urbanist(
            color: isError ? Colors.redAccent.shade100 : _kGoldLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF1A1510),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _kGold.withValues(alpha: isError ? 0.35 : 0.65)),
        ),
      ),
    );
  }

  Future<void> _orderLab() async {
    if (_isOrderingLab || _isOrderingImaging) return;
    final testName = _labTest.text.trim();
    if (testName.isEmpty) {
      _showDiagnosticSnack('Please enter a lab test name.', isError: true);
      return;
    }

    setState(() => _isOrderingLab = true);
    try {
      await widget.api.postLabOrder(
        patientUserId: widget.patientUserId,
        testName: testName,
        testType: _labType,
        appointmentId: widget.appointmentId,
      );
      if (!mounted) return;
      _labTest.clear();
      _showDiagnosticSnack('Order submitted to laboratory successfully!');
    } catch (e) {
      if (mounted) _showDiagnosticSnack(_apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isOrderingLab = false);
    }
  }

  Future<void> _orderImaging() async {
    if (_isOrderingLab || _isOrderingImaging) return;
    final studyName = _radStudy.text.trim();
    if (studyName.isEmpty) {
      _showDiagnosticSnack('Please enter a study name.', isError: true);
      return;
    }

    setState(() => _isOrderingImaging = true);
    try {
      await widget.api.postRadiologyOrder(
        patientUserId: widget.patientUserId,
        studyName: studyName,
        modality: _modality,
        appointmentId: widget.appointmentId,
      );
      if (!mounted) return;
      _radStudy.clear();
      _showDiagnosticSnack('Order submitted to radiology successfully!');
    } catch (e) {
      if (mounted) _showDiagnosticSnack(_apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isOrderingImaging = false);
    }
  }

  Future<void> _submitFullMedicalRecord() async {
    if (_submitting || _isSessionLocked) return;

    if (_condition.text.trim().isEmpty || _treatment.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least the Condition and Treatment Plan.')),
      );
      return;
    }

    final medicationName = _medName.text.trim();
    Map<String, dynamic>? prescriptionData;
    if (medicationName.isNotEmpty) {
      final valueErr = validateMedicationDurationValue(_durationQty.text);
      if (valueErr != null) {
        setState(() => _durationQtyError = valueErr);
        return;
      }
      setState(() => _durationQtyError = null);

      if (!await _safetyGate()) return;

      prescriptionData = {
        'medicationName': medicationName,
        'dosage': _dosage.text.trim(),
        'frequency': _frequency.text.trim(),
        'durationValue': _durationQty.text.trim(),
        'durationUnit': _durationUnit,
        'instructions': _instructions.text.trim(),
      };
    }

    final diagnosisData = {
      'condition': _condition.text.trim(),
      'symptoms': _symptoms.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'severity': _severity,
      'treatmentPlan': _treatment.text.trim(),
    };

    setState(() => _submitting = true);
    try {
      if (!_isActiveAppointmentSession &&
          widget.appointmentId != null &&
          widget.appointmentId!.isNotEmpty) {
        final billed = await _runSessionBilling(
          context: context,
          api: widget.api,
          patientUserId: widget.patientUserId,
          patientName: widget.patientName,
          appointmentId: widget.appointmentId,
        );
        if (!billed) {
          if (mounted) setState(() => _submitting = false);
          return;
        }
      }

      await widget.api.saveFullMedicalSession(
        patientUserId: widget.patientUserId,
        patientName: widget.patientName,
        diagnosis: diagnosisData,
        prescription: prescriptionData,
        appointmentId: widget.appointmentId,
      );

      if (!mounted) return;
      final isUpdate = _isActiveAppointmentSession;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdate
                ? (prescriptionData != null
                    ? 'Active session updated — diagnosis and prescription saved.'
                    : 'Active session updated — diagnosis saved.')
                : (prescriptionData != null
                    ? 'Medical record saved — diagnosis and prescription submitted.'
                    : 'Medical record saved — diagnosis submitted.'),
          ),
        ),
      );
      if (widget.closeOnClinicalSave) {
        _closeSheetAfterSubmit();
      } else if (_isActiveAppointmentSession) {
        await _load();
      } else {
        _closeSheetAfterSubmit();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.92;
    final locked = _isSessionLocked;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: h,
          color: _kGlass,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kGold))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.patientName,
                                  style: GoogleFonts.urbanist(color: _kGold, fontSize: 20, fontWeight: FontWeight.w700),
                                ),
                                if (widget.patientUserId.isNotEmpty)
                                  Text(
                                    'Patient ID: ${widget.patientUserId}',
                                    style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close, color: _kGoldLight), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _section('Allergies', formatAllergiesForDisplay(_emr?['allergies'])),
                          _section('Active medications', (_emr?['activeMedications'] as List?)?.length.toString() ?? '0'),
                          _section('Diagnoses', '${(_emr?['diagnoses'] as List?)?.length ?? 0} records'),
                          _section('Labs / Radiology', '${(_emr?['labRequests'] as List?)?.length ?? 0} / ${(_emr?['radiologyRequests'] as List?)?.length ?? 0}'),
                          const Divider(color: _kGold),
                          if (locked)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _kGold.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_outline, color: _kGold.withValues(alpha: 0.85), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Visit completed — this medical record is read-only.',
                                      style: GoogleFonts.urbanist(color: _kGoldLight, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            locked ? 'Clinical diagnosis (locked)' : 'Write diagnosis',
                            style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w600),
                          ),
                          TextField(
                            controller: _condition,
                            enabled: !locked,
                            readOnly: locked,
                            style: _fieldTextStyle(readOnly: locked),
                            decoration: _dec('Condition', readOnly: locked),
                          ),
                          TextField(
                            controller: _symptoms,
                            enabled: !locked,
                            readOnly: locked,
                            style: _fieldTextStyle(readOnly: locked),
                            decoration: _dec('Symptoms (comma-separated)', readOnly: locked),
                          ),
                          DropdownButtonFormField<String>(
                            value: _severity,
                            dropdownColor: const Color(0xFF1A1A18),
                            style: _fieldTextStyle(readOnly: locked),
                            decoration: _dec('Severity', readOnly: locked),
                            items: _severities.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: locked ? null : (v) => setState(() => _severity = v ?? _severity),
                          ),
                          TextField(
                            controller: _treatment,
                            enabled: !locked,
                            readOnly: locked,
                            style: _fieldTextStyle(readOnly: locked),
                            decoration: _dec('Treatment plan', readOnly: locked),
                          ),
                          const SizedBox(height: 16),
                          Text('Prescription', style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w600)),
                          TextField(
                            controller: _medName,
                            enabled: !locked,
                            readOnly: locked,
                            style: _fieldTextStyle(readOnly: locked),
                            decoration: _dec('Medication', readOnly: locked),
                          ),
                          TextField(
                            controller: _dosage,
                            enabled: !locked,
                            readOnly: locked,
                            style: _fieldTextStyle(readOnly: locked),
                            decoration: _dec('Dosage', readOnly: locked),
                          ),
                          TextField(
                            controller: _frequency,
                            enabled: !locked,
                            readOnly: locked,
                            style: _fieldTextStyle(readOnly: locked),
                            decoration: _dec('Frequency', readOnly: locked),
                          ),
                          DoctorMedicationDurationField(
                            quantityController: _durationQty,
                            unit: _durationUnit,
                            enabled: !locked,
                            onUnitChanged: (u) => setState(() => _durationUnit = u),
                            valueErrorText: _durationQtyError,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _instructions,
                            enabled: !locked,
                            readOnly: locked,
                            style: _fieldTextStyle(readOnly: locked),
                            decoration: _dec('Instructions', readOnly: locked),
                          ),
                          if (!locked) ...[
                            const SizedBox(height: 16),
                            Text('Diagnostics', style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w600)),
                            DropdownButtonFormField<String>(
                              value: _labType,
                              dropdownColor: const Color(0xFF1A1A18),
                              items: _labTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setState(() => _labType = v ?? _labType),
                              decoration: _dec('Lab type'),
                            ),
                            TextField(controller: _labTest, decoration: _dec('Lab test name')),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: (_isOrderingLab || _isOrderingImaging) ? null : _orderLab,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _kGold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _isOrderingLab
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                      )
                                    : Text('Order lab', style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _modality,
                              dropdownColor: const Color(0xFF1A1A18),
                              items: _modalities.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setState(() => _modality = v ?? _modality),
                              decoration: _dec('Radiology modality'),
                            ),
                            TextField(controller: _radStudy, decoration: _dec('Study name')),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: (_isOrderingLab || _isOrderingImaging) ? null : _orderImaging,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _kGold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _isOrderingImaging
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                      )
                                    : Text('Order imaging', style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DoctorSpecialtyPanel(specialty: widget.specialty),
                          ],
                          if (!locked) ...[
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _submitting ? null : _submitFullMedicalRecord,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _kGold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                      )
                                    : Text(
                                        _isActiveAppointmentSession
                                            ? 'Update Active Session'
                                            : 'Complete & Save Session',
                                        style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 15),
                                      ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w600)),
          Text(body, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

/// Tab 4 — specialty widgets
class DoctorSpecialtyTab extends StatelessWidget {
  const DoctorSpecialtyTab({super.key, required this.specialty});
  final String specialty;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Specialty tools', style: GoogleFonts.urbanist(color: _kGold, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        DoctorSpecialtyPanel(specialty: specialty, expanded: true),
      ],
    );
  }
}

class DoctorSpecialtyPanel extends StatelessWidget {
  const DoctorSpecialtyPanel({super.key, required this.specialty, this.expanded = false});
  final String specialty;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final s = specialty.toLowerCase();
    if (s.contains('dent')) return _dentistry(expanded);
    if (s.contains('derm')) return _dermatology(expanded);
    if (s.contains('pediat')) return _pediatrics(expanded);
    if (s.contains('gynec') || s.contains('obstet')) return _gynecology(expanded);
    return const SizedBox.shrink();
  }

  Widget _dentistry(bool ex) {
    return Card(
      color: _kGlass,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dental chart', style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: ex ? 8 : 4,
              children: List.generate(32, (i) => Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white54, fontSize: 10))),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dermatology(bool ex) {
    return Card(
      color: _kGlass,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: _imgBox('Before')),
            const SizedBox(width: 8),
            Expanded(child: _imgBox('After')),
          ],
        ),
      ),
    );
  }

  Widget _imgBox(String label) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: _kGold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white54)),
    );
  }

  Widget _pediatrics(bool ex) {
    return Card(
      color: _kGlass,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Growth & vaccines', style: GoogleFonts.urbanist(color: _kGold)),
            const SizedBox(height: 8),
            Container(height: ex ? 120 : 60, color: Colors.black26, child: const Center(child: Text('Growth chart plot', style: TextStyle(color: Colors.white38)))),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: ['BCG', 'MMR', 'DTaP', 'Polio'].map((v) => Chip(label: Text(v), backgroundColor: _kGold.withValues(alpha: 0.2))).toList()),
          ],
        ),
      ),
    );
  }

  Widget _gynecology(bool ex) {
    return Card(
      color: _kGlass,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pregnancy timeline', style: GoogleFonts.urbanist(color: _kGold)),
            ...List.generate(
              3,
              (i) => _glassMaterialListTile(
                dense: true,
                margin: EdgeInsets.zero,
                title: Text('Week ${12 + i * 4}', style: const TextStyle(color: Colors.white)),
                subtitle: const Text('Ultrasound slot', style: TextStyle(color: Colors.white54)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab 5 — patient in-app chat + nurse intercom
class DoctorCommsTab extends StatefulWidget {
  const DoctorCommsTab({super.key, required this.api, this.specialty = 'General Practice'});
  final DoctorWorkspaceApi api;
  final String specialty;

  @override
  State<DoctorCommsTab> createState() => _DoctorCommsTabState();
}

class _DoctorCommsTabState extends State<DoctorCommsTab> {
  final _msg = TextEditingController();
  final _patientId = TextEditingController();
  List<dynamic> _chatPatients = [];
  bool _loadingPatients = true;

  @override
  void dispose() {
    _msg.dispose();
    _patientId.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadChatPatients();
  }

  Future<void> _loadChatPatients() async {
    setState(() => _loadingPatients = true);
    try {
      final list = await DoctorPortalApi.getChatPatients(widget.api.doctorUserId);
      if (!mounted) return;
      setState(() {
        _chatPatients = list;
        _loadingPatients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPatients = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _openPatientChat(Map<String, dynamic> patient) {
    final patientUserId = patient['_id']?.toString() ?? patient['userId']?.toString() ?? '';
    if (patientUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient ID missing — cannot open chat.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DoctorChatRoomScreen(
          api: widget.api,
          patientUserId: patientUserId,
          patientName: patient['name']?.toString() ?? 'Patient',
        ),
      ),
    ).then((_) => _loadChatPatients());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _kGold,
      onRefresh: _loadChatPatients,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Patient messages', style: GoogleFonts.urbanist(color: _kGold, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'In-app messaging only — open a patient profile to chat or manage e-prescriptions.',
            style: GoogleFonts.urbanist(color: Colors.white54, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (_loadingPatients)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: _kGold)),
            )
          else if (_chatPatients.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'No patient conversations yet.',
                style: GoogleFonts.urbanist(color: Colors.white38),
              ),
            )
          else
            ..._chatPatients.map((raw) {
              final p = Map<String, dynamic>.from(raw as Map);
              return Card(
                color: _kGlass,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _kGold.withValues(alpha: 0.4)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _kGold.withValues(alpha: 0.2),
                    child: Text(
                      (p['name']?.toString().isNotEmpty == true ? p['name'].toString()[0] : '?').toUpperCase(),
                      style: const TextStyle(color: _kGold),
                    ),
                  ),
                  title: Text(p['name']?.toString() ?? 'Patient', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(p['email']?.toString() ?? '', style: const TextStyle(color: Colors.white54)),
                  trailing: const Icon(Icons.chevron_right, color: _kGold),
                  onTap: () => _openPatientChat(p),
                ),
              );
            }),
          const Divider(color: Colors.white12, height: 32),
          Text('Nurse intercom', style: GoogleFonts.urbanist(color: _kGold, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Dispatch instant directives to the nurse station.',
            style: GoogleFonts.urbanist(color: Colors.white54, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(controller: _patientId, style: const TextStyle(color: Colors.white), decoration: _dec('Patient user ID (optional)')),
          const SizedBox(height: 8),
          TextField(controller: _msg, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: _dec('Directive message')),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
            onPressed: () async {
              if (_msg.text.trim().isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              await widget.api.notifyNurse(message: _msg.text.trim(), patientUserId: _patientId.text.trim().isEmpty ? null : _patientId.text.trim());
              if (!mounted) return;
              messenger.showSnackBar(const SnackBar(content: Text('Sent to nurse station')));
              _msg.clear();
            },
            child: const Text('Send to nurses'),
          ),
        ],
      ),
    );
  }
}
