import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../widgets/responsive_layout.dart';
import '../../doctor_dashboard/presentation/doctor_tab_pages.dart' show mockSessionPaymentsByPatient;
import '../data/org_admin_api.dart';
import 'schedule_change_review_dialog.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFE8C547);
const Color _kGlass = Color(0xE6101A18);
const Color _kAdminSurface = Color(0xFF0D1A17);

const String _kOrgAdminEmDash = '\u2014';
const String _kOrgAdminStaffDeptFallback = 'Unassigned';
const String _kOrgAdminDoctorDeptFallback = 'General Practice';

/// Matches doctor registration specialty dropdown (professional credentials).
const List<String> _kKnownDoctorSpecialties = [
  'General Practice',
  'Cardiology',
  'Dentistry',
  'Dermatology',
  'Pediatrics',
  'Orthopedics',
  'Neurology',
  'Psychiatry',
  'Radiology',
  'Surgery',
  'Emergency Medicine',
  'Other',
];

String _sanitizeUtf8Label(String? raw) {
  if (raw == null) return '';
  var s = raw.trim();
  if (s.isEmpty) return '';
  // Reject common mojibake (UTF-8 read as Latin-1), e.g. "â€"" for an em dash.
  if (s.contains('â€') || s.contains('Ã') || s.contains('Â·') || s.contains('â†')) {
    return '';
  }
  if (s == _kOrgAdminEmDash || s == '-' || s == '—') return '';
  return s;
}

String _cellOrDash(String? raw) {
  final s = _sanitizeUtf8Label(raw);
  return s.isEmpty ? _kOrgAdminEmDash : s;
}

String? _matchKnownSpecialty(String? raw) {
  final clean = _sanitizeUtf8Label(raw);
  if (clean.isEmpty) return null;
  final lower = clean.toLowerCase();
  for (final known in _kKnownDoctorSpecialties) {
    if (known.toLowerCase() == lower) return known;
  }
  return clean;
}

Widget _title(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(t, style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 22, fontWeight: FontWeight.w700)),
    );

class OrgAdminScroll extends StatelessWidget {
  const OrgAdminScroll({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: (c.maxHeight - 40).clamp(200, double.infinity)),
          child: child,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, {this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _kGlass,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _kGold)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) Icon(icon, color: _kGold, size: 20),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Material-backed row — required when ancestor is [ColoredBox] / non-Material surface.
Widget _adminListTile({
  required Widget title,
  Widget? subtitle,
  Widget? leading,
  Widget? trailing,
  VoidCallback? onTap,
}) {
  return Card(
    color: _kAdminSurface,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: _kGold.withValues(alpha: 0.35)),
    ),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      selectedColor: _kGold,
      splashColor: _kGold.withValues(alpha: 0.12),
      onTap: onTap,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    ),
  );
}

Widget _adminSwitchTile({
  required bool value,
  required ValueChanged<bool> onChanged,
  required Widget title,
}) {
  return Card(
    color: _kAdminSurface,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: _kGold.withValues(alpha: 0.35)),
    ),
    clipBehavior: Clip.antiAlias,
    child: SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: title,
      activeThumbColor: _kGold,
    ),
  );
}

/// 0 Dashboard
class OrgAdminDashboardTab extends StatefulWidget {
  const OrgAdminDashboardTab({super.key, required this.api});
  final OrgAdminApi api;
  @override
  State<OrgAdminDashboardTab> createState() => _OrgAdminDashboardTabState();
}

class _OrgAdminDashboardTabState extends State<OrgAdminDashboardTab> {
  Map<String, dynamic>? _s;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await widget.api.getJson('/dashboard/stats');
      if (mounted) {
        setState(() {
          _s = OrgAdminApi.asMap(d);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kGold));
    final s = _s ?? {};
    final cur = s['currency'] ?? 'ILS';
    return OrgAdminScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(l10n.adminDashboardTitle),
          LayoutBuilder(
            builder: (context, constraints) {
              final r = RafeeqResponsive.of(context);
              final columns = r.isCompact ? 2 : (constraints.maxWidth >= 900 ? 3 : 2);
              final cardWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
              final cards = [
                _StatCard(l10n.adminRevenueToday, '$cur ${s['revenueToday'] ?? 0}', icon: Icons.payments),
                _StatCard(l10n.adminAppointments, '${s['appointmentsToday'] ?? 0}', icon: Icons.event),
                _StatCard(l10n.adminPendingBills, '${s['pendingInvoices'] ?? 0}', icon: Icons.receipt),
                _StatCard(l10n.adminStaff, '${s['activeStaff'] ?? 0}', icon: Icons.groups),
                _StatCard(l10n.adminPatients, '${s['registeredPatients'] ?? 0}', icon: Icons.people),
                _StatCard(l10n.adminTopDoctor, '${s['topDoctorName'] ?? l10n.patientEmDash}', icon: Icons.medical_services),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final card in cards)
                    SizedBox(width: cardWidth, child: card),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: null, color: _kGold, backgroundColor: Colors.white12),
          const SizedBox(height: 8),
          Text(l10n.adminLeaveQueue(s['pendingLeaveRequests'] as int? ?? 0), style: const TextStyle(color: Colors.white70)),
          TextButton(onPressed: _load, child: Text(l10n.adminRefresh, style: const TextStyle(color: _kGold))),
        ],
      ),
    );
  }
}

InputDecoration _dec(String l) => InputDecoration(
      labelText: l,
      labelStyle: const TextStyle(color: _kGold),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _kGold.withValues(alpha: 0.5))),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _kGold)),
    );

/// Doctor cancellation KPIs — rolling 7-day analytics (Organization Admin).
class OrgAdminDoctorAnalyticsTab extends StatefulWidget {
  const OrgAdminDoctorAnalyticsTab({super.key, required this.api});
  final OrgAdminApi api;

  @override
  State<OrgAdminDoctorAnalyticsTab> createState() => _OrgAdminDoctorAnalyticsTabState();
}

class _OrgAdminDoctorAnalyticsTabState extends State<OrgAdminDoctorAnalyticsTab> {
  Map<String, dynamic>? _payload;
  bool _loading = true;
  String? _err;

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
      final d = await widget.api.doctorAnalytics();
      if (!mounted) return;
      setState(() {
        _payload = d;
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

  Color _rateColor(String level) {
    switch (level) {
      case 'critical_review':
        return Colors.redAccent;
      case 'alert_admin':
        return Colors.orange;
      case 'warning_low':
        return Colors.yellow;
      default:
        return Colors.green;
    }
  }

  String _alertLevelLabel(BuildContext context, String level) {
    final l10n = context.l10n;
    switch (level) {
      case 'critical_review':
        return l10n.adminAlertCritical;
      case 'alert_admin':
        return l10n.adminAlertAdmin;
      case 'warning_low':
        return l10n.adminAlertWarning;
      default:
        return l10n.adminAlertNormal;
    }
  }

  Widget _adminAlertBanner(List<Map<String, dynamic>> alerts) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final d in alerts)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: d['alertLevel'] == 'critical_review' ? const Color(0xFF3A1212) : const Color(0xFF2A1F0A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: d['alertLevel'] == 'critical_review' ? Colors.redAccent : Colors.orange,
                width: 2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  d['alertLevel'] == 'critical_review' ? Icons.error_outline : Icons.warning_amber_rounded,
                  color: d['alertLevel'] == 'critical_review' ? Colors.redAccent : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        d['alertMessage']?.toString() ??
                            'Admin Alert: Doctor ${d['doctorName'] ?? ''} has exceeded the permitted cancellation rate at ${d['cancellationRate'] ?? 0}%',
                        style: GoogleFonts.urbanist(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      if (d['alertLevel'] == 'critical_review') ...[
                        const SizedBox(height: 8),
                        Text(
                          'Action required: urgent review recommended; booking restrictions may apply.',
                          style: GoogleFonts.urbanist(color: Colors.redAccent, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kGold));
    if (_err != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_err!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(context.l10n.adminRetry)),
          ],
        ),
      );
    }

    final doctors = [
      for (final raw in (_payload?['doctors'] as List<dynamic>? ?? const []))
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
    final alertDoctors = [
      for (final raw in (_payload?['alertDoctors'] as List<dynamic>? ?? const []))
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
    final weekStart = _payload?['weekStart']?.toString() ?? '';
    final weekEnd = _payload?['weekEnd']?.toString() ?? '';

    return OrgAdminScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(l10n.adminDoctorAnalyticsTitle),
          Text(
            l10n.adminRollingWeek(weekStart, weekEnd),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _adminAlertBanner(alertDoctors),
          Card(
            color: _kGlass,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: _kGold),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF1A2420)),
                columns: const [
                  DataColumn(label: Text('Doctor Name', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total Appointments', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Cancellations', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Cancellation Rate (%)', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Top Reason', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Alert Level', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold))),
                ],
                rows: [
                  for (final d in doctors)
                    DataRow(
                      cells: [
                        DataCell(Text(d['doctorName']?.toString() ?? '—', style: const TextStyle(color: Colors.white))),
                        DataCell(Text('${d['totalAppointmentsCount'] ?? 0}', style: const TextStyle(color: Colors.white70))),
                        DataCell(Text('${d['cancelledByDoctorCount'] ?? 0}', style: const TextStyle(color: Colors.white70))),
                        DataCell(
                          Text(
                            '${d['cancellationRate'] ?? 0}%',
                            style: TextStyle(
                              color: _rateColor(d['alertLevel']?.toString() ?? 'normal'),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        DataCell(Text(d['topCancellationReason']?.toString() ?? '—', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                        DataCell(
                          Text(
                            d['alertLevelLabel']?.toString() ??
                                _alertLevelLabel(context, d['alertLevel']?.toString() ?? 'normal'),
                            style: TextStyle(color: _rateColor(d['alertLevel']?.toString() ?? 'normal'), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _legendDot(Colors.green, 'Normal < 15%'),
              _legendDot(Colors.yellow, 'Low warning 15–20%'),
              _legendDot(Colors.orange, 'Admin alert > 20%'),
              _legendDot(Colors.redAccent, 'Critical > 30%'),
            ],
          ),
          TextButton(onPressed: _load, child: const Text('Refresh', style: TextStyle(color: _kGold))),
        ],
      ),
    );
  }
}

Widget _legendDot(Color c, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ],
  );
}

/// Departments wizard â€” supervisor doctor + nested clinics (no standalone clinics module).
class OrgAdminDepartmentsTab extends StatefulWidget {
  const OrgAdminDepartmentsTab({super.key, required this.api});
  final OrgAdminApi api;
  @override
  State<OrgAdminDepartmentsTab> createState() => _OrgAdminDepartmentsTabState();
}

class _OrgAdminDepartmentsTabState extends State<OrgAdminDepartmentsTab> {
  List<dynamic> _depts = [];
  List<dynamic> _doctors = [];
  bool _loading = true;

  final _deptName = TextEditingController();
  final _doctorSearch = TextEditingController();
  String? _supervisorDoctorId;

  String? _clinicDeptId;
  final _clinicName = TextEditingController();
  final _clinicPhone = TextEditingController();
  final _clinicRoom = TextEditingController();

  @override
  void dispose() {
    _deptName.dispose();
    _doctorSearch.dispose();
    _clinicName.dispose();
    _clinicPhone.dispose();
    _clinicRoom.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getJson('/departments'),
        widget.api.getJson('/doctors'),
      ]);
      if (!mounted) return;
      setState(() {
        _depts = results[0] is List ? results[0] as List<dynamic> : [];
        _doctors = results[1] is List ? results[1] as List<dynamic> : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  List<dynamic> get _filteredDoctors {
    final q = _doctorSearch.text.trim().toLowerCase();
    if (q.isEmpty) return _doctors;
    return _doctors.where((d) {
      final name = (d['name'] ?? '').toString().toLowerCase();
      final email = (d['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  Future<void> _createDepartment() async {
    final name = _deptName.text.trim();
    if (name.isEmpty) return;
    try {
      await widget.api.postJson('/departments', {
        'name': name,
        if (_supervisorDoctorId != null && _supervisorDoctorId!.isNotEmpty) 'supervisorDoctorId': _supervisorDoctorId,
      });
      _deptName.clear();
      setState(() => _supervisorDoctorId = null);
      await _loadAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department created')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addClinic() async {
    final deptId = _clinicDeptId;
    final name = _clinicName.text.trim();
    if (deptId == null || name.isEmpty) return;
    try {
      await widget.api.postJson('/departments/$deptId/clinics', {
        'name': name,
        'phone': _clinicPhone.text.trim(),
        'roomNumber': _clinicRoom.text.trim(),
      });
      _clinicName.clear();
      _clinicPhone.clear();
      _clinicRoom.clear();
      await _loadAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clinic added to department')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      color: _kGlass,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _kGold.withValues(alpha: 0.6))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: GoogleFonts.poppins(color: _kGold, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _departmentPreviewCard(Map<String, dynamic> d) {
    final sup = d['supervisorDoctor'] as Map?;
    final supName = sup?['name']?.toString() ?? 'No supervisor assigned';
    final clinics = (d['clinics'] as List?) ?? [];

    return Card(
      color: _kGlass,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _kGold, width: 1.2)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d['name']?.toString() ?? 'Department',
              style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.medical_services_outlined, color: _kGold, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Supervisor: $supName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Clinics (${clinics.length})', style: TextStyle(color: _kGold.withValues(alpha: 0.9), fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            if (clinics.isEmpty)
              const Text('No clinics registered yet.', style: TextStyle(color: Colors.white38, fontSize: 12))
            else
              ...clinics.map((c) {
                final m = c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{};
                final room = m['roomNumber']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.local_hospital_outlined, color: _kGold, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['name']?.toString() ?? 'Clinic', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                            Text(
                              [m['phone']?.toString(), if (room.isNotEmpty) 'Room $room'].where((s) => s != null && s.toString().isNotEmpty).join(' Â· '),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kGold));

    return OrgAdminScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('Departments wizard'),
          _sectionCard(
            title: 'Create department',
            children: [
              TextField(
                controller: _deptName,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Department name (e.g. Bones, Pediatrics)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _doctorSearch,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Search doctors'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('sup-${_filteredDoctors.length}-${_doctorSearch.text}'),
                value: _filteredDoctors.any((d) => d['_id']?.toString() == _supervisorDoctorId) ? _supervisorDoctorId : null,
                dropdownColor: const Color(0xFF1A2220),
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Supervisor doctor'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('â€” None â€”', style: TextStyle(color: Colors.white54))),
                  ..._filteredDoctors.map((doc) {
                    final id = doc['_id']?.toString() ?? '';
                    return DropdownMenuItem(
                      value: id,
                      child: Text('${doc['name']} Â· ${doc['email']}', style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (v) => setState(() => _supervisorDoctorId = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
                onPressed: _createDepartment,
                child: const Text('Create department'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Add clinic inside department',
            children: [
              DropdownButtonFormField<String>(
                value: _depts.any((d) => d['_id']?.toString() == _clinicDeptId) ? _clinicDeptId : null,
                dropdownColor: const Color(0xFF1A2220),
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Select department'),
                items: _depts
                    .map((d) => DropdownMenuItem(
                          value: d['_id']?.toString(),
                          child: Text(d['name']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _clinicDeptId = v),
              ),
              const SizedBox(height: 10),
              TextField(controller: _clinicName, style: const TextStyle(color: Colors.white), decoration: _dec('Clinic name')),
              TextField(controller: _clinicPhone, style: const TextStyle(color: Colors.white), decoration: _dec('Phone')),
              TextField(controller: _clinicRoom, style: const TextStyle(color: Colors.white), decoration: _dec('Room number (optional)')),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
                onPressed: _addClinic,
                child: const Text('Add clinic to department'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Registered departments', style: GoogleFonts.poppins(color: _kGold, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (_depts.isEmpty)
            const Text('No departments yet. Create one above.', style: TextStyle(color: Colors.white54))
          else
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 720 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 220,
                  ),
                  itemCount: _depts.length,
                  itemBuilder: (_, i) {
                    final d = Map<String, dynamic>.from(_depts[i] as Map);
                    return _departmentPreviewCard(d);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

const _staffPermissionScopes = [
  'view_medical_notes',
  'view_invoices',
  'manage_staff',
  'manage_appointments',
];

const _weekDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/// 3 Staff roster & nurse onboarding approvals
class OrgAdminStaffTab extends StatefulWidget {
  const OrgAdminStaffTab({super.key, required this.api});
  final OrgAdminApi api;
  @override
  State<OrgAdminStaffTab> createState() => _OrgAdminStaffTabState();
}

class _OrgAdminStaffTabState extends State<OrgAdminStaffTab> {
  List<dynamic> _staff = [];
  List<dynamic> _pending = [];
  List<dynamic> _pendingRegistrations = [];
  List<dynamic> _pendingScheduleRequests = [];
  List<dynamic> _depts = [];
  List<dynamic> _doctors = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = _search.text.trim().isEmpty ? null : {'q': _search.text.trim()};
      final results = await Future.wait([
        widget.api.getJson('/staff', query: q),
        widget.api.getJson('/pending-staff'),
        widget.api.getJson('/pending-registrations'),
        widget.api.getJson('/schedule-change-requests'),
        widget.api.getJson('/departments'),
        widget.api.getJson('/doctors'),
      ]);
      if (!mounted) return;
      setState(() {
        _staff = results[0] is List ? results[0] as List<dynamic> : [];
        _pending = results[1] is List ? results[1] as List<dynamic> : [];
        _pendingRegistrations = results[2] is List ? results[2] as List<dynamic> : [];
        _pendingScheduleRequests = results[3] is List ? results[3] as List<dynamic> : [];
        _depts = results[4] is List ? results[4] as List<dynamic> : [];
        _doctors = results[5] is List ? results[5] as List<dynamic> : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _deptNameById(String? deptId) {
    if (deptId == null || deptId.isEmpty) return '';
    for (final raw in _depts) {
      if (raw is! Map) continue;
      final d = Map<String, dynamic>.from(raw);
      final id = (d['_id'] ?? d['id'])?.toString();
      if (id == deptId) {
        return _sanitizeUtf8Label(d['name']?.toString());
      }
    }
    return '';
  }

  /// Resolves the department column for the active staff roster.
  String _resolveStaffDepartmentLabel(Map<String, dynamic> staffRow) {
    final profile = staffRow['profile'] is Map
        ? Map<String, dynamic>.from(staffRow['profile'] as Map)
        : null;
    final role = _sanitizeUtf8Label(staffRow['role']?.toString()).toLowerCase();

    final deptObj = staffRow['department'];
    if (deptObj is Map) {
      final name = _sanitizeUtf8Label(deptObj['name']?.toString());
      if (name.isNotEmpty) return name;
    } else {
      final flat = _sanitizeUtf8Label(deptObj?.toString());
      if (flat.isNotEmpty) return flat;
    }

    if (profile?['department'] is Map) {
      final name = _sanitizeUtf8Label(
        (profile!['department'] as Map)['name']?.toString(),
      );
      if (name.isNotEmpty) return name;
    }

    final deptId = (profile?['departmentId'] ?? staffRow['departmentId'])?.toString();
    final deptName = _deptNameById(deptId);
    if (deptName.isNotEmpty) return deptName;

    for (final candidate in [
      profile?['specialty'],
      profile?['specialization'],
      staffRow['specialty'],
      staffRow['specialization'],
      staffRow['doctorSpecialization'],
    ]) {
      final specialty = _matchKnownSpecialty(candidate?.toString());
      if (specialty != null && specialty.isNotEmpty) return specialty;
    }

    if (role == 'doctor') return _kOrgAdminDoctorDeptFallback;
    return _kOrgAdminStaffDeptFallback;
  }

  Future<void> _approveRegistration(String requestId) async {
    try {
      await widget.api.postJson('/pending-registrations/$requestId/approve', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration approved â€” account activated')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _rejectRegistration(String requestId) async {
    try {
      await widget.api.postJson('/pending-registrations/$requestId/reject', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration rejected')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _approveScheduleRequest(String requestId) async {
    try {
      await widget.api.postJson('/schedule-change-requests/$requestId/approve', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule approved â€” doctor hours updated')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _rejectScheduleRequest(String requestId) async {
    try {
      await widget.api.postJson('/schedule-change-requests/$requestId/reject', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule change rejected')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kGold));
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return OrgAdminScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context.l10n.adminStaffOnboarding),
          TextField(
            controller: _search,
            style: const TextStyle(color: Colors.white),
            decoration: _dec(context.l10n.adminSearchActiveStaff),
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Pending doctor & staff requests (${_pendingRegistrations.length})',
                style: const TextStyle(color: _kGold, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh, color: _kGold), onPressed: _load),
            ],
          ),
          const SizedBox(height: 8),
          if (_pendingRegistrations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No pending doctor or legacy staff registration requests.', style: TextStyle(color: Colors.white54)),
            )
          else
            Card(
              color: _kGlass,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _kGold)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: GoogleFonts.poppins(color: _kGold, fontSize: 12, fontWeight: FontWeight.w600),
                  dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
                  columns: const [
                    DataColumn(label: Text('Applicant')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Specialty')),
                    DataColumn(label: Text('Applied')),
                    DataColumn(label: Text('')),
                  ],
                  rows: _pendingRegistrations.map((raw) {
                    final m = Map<String, dynamic>.from(raw as Map);
                    final id = m['_id']?.toString() ?? '';
                    final created = m['createdAt']?.toString() ?? '';
                    final dateLabel = created.length >= 10 ? created.substring(0, 10) : 'â€”';
                    final profile = m['doctorProfile'] is Map ? Map<String, dynamic>.from(m['doctorProfile'] as Map) : <String, dynamic>{};
                    return DataRow(
                      cells: [
                        DataCell(Text(m['name']?.toString() ?? profile['fullName']?.toString() ?? m['email']?.toString() ?? 'â€”')),
                        DataCell(Text(m['role']?.toString() ?? 'â€”')),
                        DataCell(Text(profile['specialty']?.toString() ?? m['doctorSpecialization']?.toString() ?? 'â€”')),
                        DataCell(Text(dateLabel)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: id.isEmpty ? null : () => _approveRegistration(id),
                                child: Text(context.l10n.adminApprove, style: const TextStyle(color: _kGold)),
                              ),
                              TextButton(
                                onPressed: id.isEmpty ? null : () => _rejectRegistration(id),
                                child: Text(context.l10n.adminReject, style: const TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Pending doctor schedule changes (${_pendingScheduleRequests.length})',
            style: const TextStyle(color: _kGold, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_pendingScheduleRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No pending working-hours change requests.', style: TextStyle(color: Colors.white54)),
            )
          else
            Card(
              color: _kGlass,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _kGold)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: GoogleFonts.poppins(color: _kGold, fontSize: 12, fontWeight: FontWeight.w600),
                  dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
                  columns: const [
                    DataColumn(label: Text('Doctor')),
                    DataColumn(label: Text('Schedule preview')),
                    DataColumn(label: Text('Requested')),
                    DataColumn(label: Text('')),
                  ],
                  rows: _pendingScheduleRequests.map((raw) {
                    final m = Map<String, dynamic>.from(raw as Map);
                    final id = m['_id']?.toString() ?? '';
                    final created = m['createdAt']?.toString() ?? '';
                    final dateLabel = created.length >= 10 ? created.substring(0, 10) : 'â€”';
                    final preview = scheduleInlinePreview(m);
                    final activeDays = m['activeDayCount'] ?? parseScheduleBreakdown(m).where((d) => d.enabled).length;
                    return DataRow(
                      cells: [
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(m['doctorDisplayName']?.toString() ?? 'â€”'),
                              Text(
                                '$activeDays active day(s)',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Text(
                              preview,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(dateLabel)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: id.isEmpty
                                    ? null
                                    : () => showScheduleChangeReviewDialog(
                                          context,
                                          request: m,
                                          onApprove: () => _approveScheduleRequest(id),
                                          onReject: () => _rejectScheduleRequest(id),
                                        ),
                                child: Text(
                                  isAr ? 'Ø¹Ø±Ø¶ Ø§Ù„ØªÙØ§ØµÙŠÙ„' : 'Review',
                                  style: const TextStyle(color: Color(0xFFFFE8A3)),
                                ),
                              ),
                              TextButton(
                                onPressed: id.isEmpty ? null : () => _approveScheduleRequest(id),
                                child: Text(context.l10n.adminApprove, style: const TextStyle(color: _kGold)),
                              ),
                              TextButton(
                                onPressed: id.isEmpty ? null : () => _rejectScheduleRequest(id),
                                child: Text(context.l10n.adminReject, style: const TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text('Pending nurse applications (${_pending.length})', style: TextStyle(color: _kGold.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_pending.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No pending clinical staff registrations.', style: TextStyle(color: Colors.white54)),
            )
          else
            Card(
              color: _kGlass,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _kGold)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: GoogleFonts.poppins(color: _kGold, fontSize: 12, fontWeight: FontWeight.w600),
                  dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
                  columns: const [
                    DataColumn(label: Text('Applicant')),
                    DataColumn(label: Text('Specialty')),
                    DataColumn(label: Text('License')),
                    DataColumn(label: Text('Applied')),
                    DataColumn(label: Text('')),
                  ],
                  rows: _pending.map((raw) {
                    final m = Map<String, dynamic>.from(raw as Map);
                    final name = m['fullName']?.toString() ?? '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
                    final id = m['_id']?.toString() ?? '';
                    return DataRow(
                      cells: [
                        DataCell(Text(name.isEmpty ? _kOrgAdminEmDash : name)),
                        DataCell(Text(_matchKnownSpecialty(m['specialty']?.toString()) ?? _kOrgAdminDoctorDeptFallback)),
                        DataCell(Text(_cellOrDash(m['licenseNumber']?.toString()))),
                        DataCell(Text(
                          (m['createdAt']?.toString() ?? '').length >= 10
                              ? (m['createdAt'] as String).substring(0, 10)
                              : _kOrgAdminEmDash,
                        )),
                        DataCell(
                          TextButton(
                            onPressed: id.isEmpty ? null : () => _openPendingReview(m),
                            child: Text(context.l10n.adminReview, style: const TextStyle(color: _kGold)),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 20),
          _title('Active staff roster'),
          if (_staff.isEmpty)
            const Text('No staff records.', style: TextStyle(color: Colors.white54))
          else
            Card(
              color: _kGlass,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _kGold)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: GoogleFonts.poppins(color: _kGold, fontSize: 12, fontWeight: FontWeight.w600),
                  dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Department')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _staff.map((raw) {
                    final m = Map<String, dynamic>.from(raw as Map);
                    return DataRow(
                      cells: [
                        DataCell(Text(_cellOrDash(m['name']?.toString()))),
                        DataCell(Text(_cellOrDash(m['role']?.toString()))),
                        DataCell(
                          Text(
                            _resolveStaffDepartmentLabel(m),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        DataCell(Text(_cellOrDash(m['status']?.toString()))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openPendingReview(Map<String, dynamic> applicant) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _StaffApprovalPanel(
        applicant: applicant,
        onClose: () => Navigator.pop(ctx),
        onDecided: () async {
          Navigator.pop(ctx);
          await _load();
        },
        approve: (body) => widget.api.putJson('/approve-staff/${applicant['_id']}', body),
      ),
    );
  }
}

class _StaffApprovalPanel extends StatefulWidget {
  const _StaffApprovalPanel({
    required this.applicant,
    required this.onClose,
    required this.onDecided,
    required this.approve,
  });

  final Map<String, dynamic> applicant;
  final VoidCallback onClose;
  final Future<void> Function() onDecided;
  final Future<dynamic> Function(Map<String, dynamic> body) approve;

  @override
  State<_StaffApprovalPanel> createState() => _StaffApprovalPanelState();
}

class _StaffApprovalPanelState extends State<_StaffApprovalPanel> {
  final _salary = TextEditingController();
  final _shiftStart = TextEditingController(text: '08:00');
  final _shiftEnd = TextEditingController(text: '17:00');
  final Set<String> _permissions = {};
  final Set<String> _selectedDays = {};
  bool _busy = false;

  @override
  void dispose() {
    _salary.dispose();
    _shiftStart.dispose();
    _shiftEnd.dispose();
    super.dispose();
  }

  String _s(dynamic v) => v?.toString() ?? 'â€”';

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(label, style: const TextStyle(color: _kGold, fontSize: 12))),
            Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          ],
        ),
      );

  Widget _section(String title, List<Widget> children) => Card(
        color: _kGlass,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _kGold.withValues(alpha: 0.5))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: GoogleFonts.poppins(color: _kGold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );

  List<Map<String, String>> _buildShifts() {
    final start = _shiftStart.text.trim().isEmpty ? '08:00' : _shiftStart.text.trim();
    final end = _shiftEnd.text.trim().isEmpty ? '17:00' : _shiftEnd.text.trim();
    return _selectedDays.map((d) => {'day': d, 'startTime': start, 'endTime': end}).toList();
  }

  Future<void> _submitApprove() async {
    setState(() => _busy = true);
    try {
      await widget.approve({
        'action': 'approve',
        if (_salary.text.trim().isNotEmpty) 'salary': num.tryParse(_salary.text.trim()) ?? 0,
        'permissions': _permissions.toList(),
        'workingDaysAndHours': _buildShifts(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff approved and account activated')));
      await widget.onDecided();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.applicant;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Dialog(
      backgroundColor: const Color(0xFF0D1210),
      insetPadding: EdgeInsets.symmetric(horizontal: wide ? 48 : 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 1100 : 560, maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Review: ${a['fullName'] ?? '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim()}',
                      style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, color: Colors.white54)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _applicantColumn(a)),
                          const SizedBox(width: 16),
                          Expanded(child: _adminColumn()),
                        ],
                      )
                    : Column(
                        children: [
                          _applicantColumn(a),
                          const SizedBox(height: 8),
                          _adminColumn(),
                        ],
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submitApprove,
                  style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(_busy ? 'Processing…' : 'Approve & activate'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _applicantColumn(Map<String, dynamic> a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Personal', [
          _detailRow('Username', _s(a['username'])),
          _detailRow('Email', _s(a['email'])),
          _detailRow('Phone', _s(a['phone'])),
          _detailRow('Gender', _s(a['gender'])),
          _detailRow('Birth date', _s(a['birthDate'])),
        ]),
        _section('Professional', [
          _detailRow('Employee ID', _s(a['employeeId'])),
          _detailRow('Specialty', _s(a['specialtyOrDepartment'])),
          _detailRow('Experience', '${a['experienceYears'] ?? 0} years'),
          _detailRow('Education', _s(a['educationLevel'])),
          _detailRow('University', _s(a['university'])),
          _detailRow('License #', _s(a['nursingLicenseNumber'])),
          _detailRow('License expiry', _s(a['licenseExpiryDate'])),
          _detailRow('Employment', _s(a['employmentType'])),
        ]),
      ],
    );
  }

  Widget _adminColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Administrative assignment', [
          TextField(
            controller: _salary,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('Monthly salary (optional)'),
          ),
        ]),
        _section('Working schedule', [
          Row(
            children: [
              Expanded(child: TextField(controller: _shiftStart, style: const TextStyle(color: Colors.white), decoration: _dec('Start (HH:mm)'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _shiftEnd, style: const TextStyle(color: Colors.white), decoration: _dec('End (HH:mm)'))),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 0,
            children: _weekDays.map((day) {
              final on = _selectedDays.contains(day);
              return FilterChip(
                label: Text(day.substring(0, 3), style: TextStyle(color: on ? Colors.black : Colors.white70, fontSize: 11)),
                selected: on,
                selectedColor: _kGold,
                checkmarkColor: Colors.black,
                backgroundColor: Colors.white10,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ]),
        _section('Permission flags', [
          ..._staffPermissionScopes.map((s) => CheckboxListTile(
                dense: true,
                value: _permissions.contains(s),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _permissions.add(s);
                    } else {
                      _permissions.remove(s);
                    }
                  });
                },
                title: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                activeColor: _kGold,
              )),
        ]),
      ],
    );
  }
}

/// 4 Patients — read-only clinic directory (live API)
class OrgAdminPatientsTab extends StatefulWidget {
  const OrgAdminPatientsTab({super.key, required this.api});
  final OrgAdminApi api;
  @override
  State<OrgAdminPatientsTab> createState() => _OrgAdminPatientsTabState();
}

class _PatientsDirectoryData {
  const _PatientsDirectoryData({
    required this.patients,
    required this.unpaidByPatientId,
  });

  final List<Map<String, dynamic>> patients;
  final Map<String, double> unpaidByPatientId;
}

class _OrgAdminPatientsTabState extends State<OrgAdminPatientsTab> {
  late Future<_PatientsDirectoryData> _patientsFuture;
  bool _unpaidOnly = false;

  @override
  void initState() {
    super.initState();
    _patientsFuture = _fetchPatients();
  }

  Future<_PatientsDirectoryData> _fetchPatients() async {
    final patients = await widget.api.getClinicPatients();
    final unpaidByPatientId = <String, double>{};

    try {
      final ledger = OrgAdminApi.asMapList(await widget.api.getJson('/billing/ledger'));
      for (final row in ledger) {
        if ((row['status']?.toString() ?? '') != 'Pending') continue;
        final pid = row['patientUserId']?.toString().trim() ?? '';
        if (pid.isEmpty) continue;
        unpaidByPatientId[pid] =
            (unpaidByPatientId[pid] ?? 0) + OrgAdminApi.asDouble(row['amount']);
      }
    } catch (_) {}

    for (final entry in mockSessionPaymentsByPatient.entries) {
      for (final payment in entry.value) {
        if ((payment['status']?.toString() ?? '') != 'Pending') continue;
        unpaidByPatientId[entry.key] =
            (unpaidByPatientId[entry.key] ?? 0) + OrgAdminApi.asDouble(payment['amount']);
      }
    }

    return _PatientsDirectoryData(
      patients: patients,
      unpaidByPatientId: unpaidByPatientId,
    );
  }

  void _refreshPatients() {
    setState(() {
      _patientsFuture = _fetchPatients();
    });
  }

  String _cellText(dynamic value, {String fallback = _kOrgAdminEmDash}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  String _patientId(Map<String, dynamic> p) {
    return _cellText(
      p['patientId'] ?? p['id'] ?? p['userId'],
      fallback: '',
    );
  }

  String _patientDisplayName(Map<String, dynamic> p) {
    final fullName = p['fullName']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;
    final name = p['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final user = p['user'];
    if (user is Map) {
      final userName = user['name']?.toString().trim();
      if (userName != null && userName.isNotEmpty) return userName;
    }
    return _kOrgAdminEmDash;
  }

  String _assignedDoctorLabel(Map<String, dynamic> p) {
    String? raw = p['assignedDoctorName']?.toString().trim();
    raw = (raw != null && raw.isNotEmpty) ? raw : p['doctorName']?.toString().trim();
    if (raw == null || raw.isEmpty) {
      final doctor = p['doctorId'];
      if (doctor is Map) {
        raw = doctor['name']?.toString().trim() ??
            doctor['displayName']?.toString().trim() ??
            doctor['fullName']?.toString().trim();
      } else if (p['doctor'] is Map) {
        final doc = p['doctor'] as Map;
        raw = doc['name']?.toString().trim() ??
            doc['displayName']?.toString().trim() ??
            doc['fullName']?.toString().trim();
      }
    }
    if (raw == null || raw.isEmpty) return 'Assigned doctor pending';
    return raw.startsWith('Dr.') ? raw : 'Dr. $raw';
  }

  String _patientStatusSubtitle(Map<String, dynamic> p) {
    final parts = <String>[];
    final age = p['age'];
    if (age is num && age > 0) parts.add('${age.toInt()} yrs');
    final gender = p['gender']?.toString().trim();
    if (gender != null && gender.isNotEmpty) parts.add(gender);
    if (parts.isNotEmpty) return parts.join(' · ');
    final email = p['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;
    final phone = p['phone']?.toString().trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return _assignedDoctorLabel(p);
  }

  double _unpaidBalance(Map<String, dynamic> p, Map<String, double> unpaidMap) {
    final pid = _patientId(p);
    if (pid.isEmpty) return 0;
    return unpaidMap[pid] ?? 0;
  }

  String _formatIls(double amount) {
    final formatted =
        amount.truncateToDouble() == amount ? amount.toInt().toString() : amount.toStringAsFixed(2);
    return '$formatted ILS';
  }

  Widget _infoChip(String label, {Color? bg, Color? fg}) {
    final foreground = fg ?? _kGoldLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg ?? _kGold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(color: foreground, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _statusInfoCell(Map<String, dynamic> p, double unpaid) {
    final bloodType = p['bloodType']?.toString().trim() ?? '';
    final doctor = _assignedDoctorLabel(p);
    final subtitle = _patientStatusSubtitle(p);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          doctor,
          style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        if (subtitle.isNotEmpty && subtitle != doctor) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
          ),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (unpaid > 0)
              _infoChip(
                context.l10n.adminUnpaidBalance(_formatIls(unpaid)),
                bg: Colors.red.withValues(alpha: 0.16),
                fg: Colors.redAccent.shade100,
              )
            else
              _infoChip('Balance clear', bg: Colors.green.withValues(alpha: 0.14), fg: Colors.greenAccent.shade100),
            if (bloodType.isNotEmpty && bloodType != '—') _infoChip('Blood $bloodType'),
          ],
        ),
      ],
    );
  }

  Widget _patientsTable(
    List<Map<String, dynamic>> rows,
    Map<String, double> unpaidMap, {
    required String emptyMessage,
  }) {
    return Card(
      color: _kGlass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _kGold.withValues(alpha: 0.45)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(const Color(0xFF1A2420)),
          dataRowMinHeight: 72,
          dataRowMaxHeight: 96,
          columnSpacing: 28,
          headingTextStyle: GoogleFonts.urbanist(
            color: _kGold,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          columns: const [
            DataColumn(label: Text('Patient ID')),
            DataColumn(label: Text('Patient Name')),
            DataColumn(label: Text('Status / Info')),
          ],
          rows: rows.isEmpty
              ? [
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          _kOrgAdminEmDash,
                          style: GoogleFonts.urbanist(color: Colors.white38),
                        ),
                      ),
                      DataCell(
                        Text(
                          emptyMessage,
                          style: GoogleFonts.urbanist(color: Colors.white54),
                        ),
                      ),
                      const DataCell(SizedBox.shrink()),
                    ],
                  ),
                ]
              : [
                  for (final p in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            _patientId(p),
                            style: GoogleFonts.urbanist(
                              color: _kGoldLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _patientDisplayName(p),
                            style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(_statusInfoCell(p, _unpaidBalance(p, unpaidMap))),
                      ],
                    ),
                ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrgAdminScroll(
      child: FutureBuilder<_PatientsDirectoryData>(
        future: _patientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _title('Patient directory'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator(color: _kGold)),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _title('Patient directory'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _refreshPatients,
                    child: const Text('Retry', style: TextStyle(color: _kGold)),
                  ),
                ),
              ],
            );
          }

          final data = snapshot.data!;
          final unpaidMap = data.unpaidByPatientId;
          var rows = data.patients;
          if (_unpaidOnly) {
            rows = rows
                .where((p) => _unpaidBalance(p, unpaidMap) > 0)
                .toList(growable: false);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _title('Patient directory')),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _refreshPatients,
                    icon: const Icon(Icons.refresh, color: _kGold),
                  ),
                ],
              ),
              Text(
                'Read-only clinic roster — monitor patients globally without opening medical records.',
                style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.adminUnpaidOnly,
                      style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  Switch(
                    value: _unpaidOnly,
                    activeThumbColor: _kGold,
                    activeTrackColor: _kGold.withValues(alpha: 0.45),
                    inactiveThumbColor: Colors.white54,
                    inactiveTrackColor: Colors.white12,
                    onChanged: (v) => setState(() => _unpaidOnly = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _patientsTable(
                rows,
                unpaidMap,
                emptyMessage: _unpaidOnly
                    ? 'No patients with unpaid balances for this clinic.'
                    : 'No patients registered for this clinic.',
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Presentation-mode clinic appointments — single confirmed visit for admin tab.
List<Map<String, dynamic>> _kDefaultAdminAppointments() => [
      {
        'appointmentId': 'APP-98421',
        'id': 'APP-98421',
        'patientName': 'Patient',
        'doctorName': 'doctor',
        'date': '2026-06-15',
        'time': '10:30 AM',
        'status': 'Confirmed',
      },
    ];

/// 5 Appointments — read-only clinic roster (presentation mock)
class OrgAdminAppointmentsTab extends StatefulWidget {
  const OrgAdminAppointmentsTab({super.key, required this.api});
  final OrgAdminApi api;
  @override
  State<OrgAdminAppointmentsTab> createState() => _OrgAdminAppointmentsTabState();
}

class _OrgAdminAppointmentsTabState extends State<OrgAdminAppointmentsTab> {
  List<Map<String, dynamic>> _appointments = _kDefaultAdminAppointments();

  // Bypassed — GET /api/appointments/clinic returns Route not found in demo environment.
  // Future<List<Map<String, dynamic>>> _fetchClinicAppointments() {
  //   return widget.api.getClinicAppointments();
  // }

  void _refreshAppointments() {
    setState(() {
      _appointments = _kDefaultAdminAppointments()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    });
  }

  String _cellText(dynamic value, {String fallback = _kOrgAdminEmDash}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  String _doctorDisplayName(Map<String, dynamic> a) {
    final raw = _cellText(a['doctorName'], fallback: '');
    if (raw.isEmpty) return 'Assigned doctor pending';
    if (raw == 'doctor') return raw;
    return raw.startsWith('Dr.') ? raw : 'Dr. $raw';
  }

  String _statusLabel(String status) {
    final s = status.toLowerCase();
    if (s.contains('confirm')) return 'Confirmed';
    if (s.contains('cancel')) {
      if (s.contains('doctor')) return 'Cancelled (Doctor)';
      if (s.contains('patient')) return 'Cancelled (Patient)';
      return 'Cancelled';
    }
    if (s.contains('accept') || s == 'booked') return 'Accepted';
    if (s.contains('pending')) return 'Pending';
    if (s.contains('progress')) return 'In Progress';
    if (s.contains('complete')) return 'Completed';
    return status.isEmpty ? 'Active' : status;
  }

  ({Color bg, Color fg}) _statusColors(String status) {
    final s = status.toLowerCase();
    if (s.contains('confirm')) {
      return (bg: const Color(0xFF004D40).withValues(alpha: 0.45), fg: const Color(0xFF4DB6AC));
    }
    if (s.contains('cancel') || s.contains('reject')) {
      return (bg: Colors.red.withValues(alpha: 0.16), fg: Colors.redAccent.shade100);
    }
    if (s.contains('accept') ||
        s.contains('active') ||
        s.contains('book') ||
        s.contains('progress') ||
        s.contains('complete')) {
      return (bg: Colors.green.withValues(alpha: 0.16), fg: Colors.greenAccent.shade100);
    }
    return (bg: _kGold.withValues(alpha: 0.14), fg: _kGoldLight);
  }

  Widget _statusChip(String status) {
    final label = _statusLabel(status);
    final colors = _statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.fg.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(color: colors.fg, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _appointments;

    return OrgAdminScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _title('Clinic appointments')),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refreshAppointments,
                icon: const Icon(Icons.refresh, color: _kGold),
              ),
            ],
          ),
          Text(
            'Read-only view of scheduled visits for your clinic.',
            style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          Card(
            color: _kGlass,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _kGold.withValues(alpha: 0.45)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 48),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF1A2420)),
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 64,
                  columnSpacing: 24,
                  headingTextStyle: GoogleFonts.urbanist(
                    color: _kGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  columns: const [
                    DataColumn(label: Text('Appointment ID')),
                    DataColumn(label: Text('Patient Name')),
                    DataColumn(label: Text('Doctor Name')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Time')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: [
                    for (final a in items)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              _cellText(a['appointmentId'] ?? a['id']),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              _cellText(a['patientName']),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(
                            Text(
                              _doctorDisplayName(a),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.urbanist(color: Colors.white70),
                            ),
                          ),
                          DataCell(
                            Text(
                              _cellText(a['date']),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.urbanist(color: Colors.white70),
                            ),
                          ),
                          DataCell(
                            Text(
                              _cellText(a['time']),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(_statusChip(_cellText(a['status'], fallback: 'Confirmed'))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 6 Attendance & leave
class OrgAdminLeaveTab extends StatefulWidget {
  const OrgAdminLeaveTab({super.key, required this.api});
  final OrgAdminApi api;
  @override
  State<OrgAdminLeaveTab> createState() => _OrgAdminLeaveTabState();
}

class _OrgAdminLeaveTabState extends State<OrgAdminLeaveTab> {
  List<dynamic> _staffLeave = [];
  List<dynamic> _doctorLeave = [];
  final _rejectReason = TextEditingController();

  @override
  void dispose() {
    _rejectReason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await widget.api.getJson('/staff-leave-requests');
    final d = await widget.api.getJson('/doctor-leave-requests');
    if (mounted) setState(() {
      _staffLeave = s is List ? s : [];
      _doctorLeave = d is List ? d : [];
    });
  }

  Future<void> _decideStaff(String id, String status) async {
    await widget.api.patchJson('/staff-leave-requests/$id', {
      'status': status,
      if (status == 'Rejected') 'rejectionReason': _rejectReason.text.trim(),
    });
    await _load();
  }

  Future<void> _decideDoctor(String id, String status) async {
    await widget.api.patchJson('/doctor-leave-requests/$id', {'status': status});
    await _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return OrgAdminScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('Attendance & leave'),
          TextField(controller: _rejectReason, style: const TextStyle(color: Colors.white), decoration: _dec('Rejection reason (optional)')),
          Text('Staff leave', style: TextStyle(color: _kGold, fontWeight: FontWeight.w600)),
          ..._staffLeave.map((m) => _leaveCard(m, onApprove: () => _decideStaff('${m['_id']}', 'Approved'), onReject: () => _decideStaff('${m['_id']}', 'Rejected'))),
          Text('Doctor leave', style: TextStyle(color: _kGold, fontWeight: FontWeight.w600)),
          ..._doctorLeave.map((m) => _leaveCard(m, onApprove: () => _decideDoctor('${m['_id']}', 'Approved'), onReject: () => _decideDoctor('${m['_id']}', 'Rejected'))),
        ],
      ),
    );
  }

  Widget _leaveCard(Map m, {required VoidCallback onApprove, required VoidCallback onReject}) {
    final name = m['applicantName'] ?? m['doctorName'] ?? m['name'] ?? 'Applicant';
    final email = m['applicantEmail'] ?? m['doctorEmail'] ?? '';
    final type = m['type'] ?? m['leaveType'] ?? 'Leave';
    final from = m['fromDate'] ?? m['startDate'] ?? '—';
    final to = m['toDate'] ?? m['endDate'] ?? '—';
    return Card(
      color: _kGlass,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w700, fontSize: 14)),
            if (email.toString().isNotEmpty)
              Text(email.toString(), style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              '$type · $from → $to',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'Status: ${m['status'] ?? 'Pending'}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Row(
              children: [
                TextButton(onPressed: onApprove, child: const Text('Approve', style: TextStyle(color: Colors.greenAccent))),
                TextButton(onPressed: onReject, child: const Text('Reject', style: TextStyle(color: Colors.redAccent))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Presentation-mode billing ledger — single paid consultation for admin billing tab.
List<Map<String, dynamic>> _kDefaultAdminPaymentHistory() => [
      {
        'transactionId': 'PAY-14527',
        'id': 'PAY-14527',
        'patientName': 'Patient',
        'serviceType': 'Consultation Fee (doctor)',
        'status': 'Paid',
        'amount': 100.0,
        'currency': 'ILS',
      },
    ];

List<Map<String, dynamic>> _kDefaultAdminDoctors() => [
      {
        '_id': 'demo-doctor',
        'userId': 'demo-doctor',
        'name': 'doctor',
        'displayName': 'doctor',
        'email': 'doctor@rafeeq.local',
      },
    ];

double _ledgerAmountSum(List<Map<String, dynamic>> rows) => rows.fold<double>(
      0.0,
      (sum, item) => sum + OrgAdminApi.asDouble(item['amount']),
    );

double _ledgerPaidAmountSum(List<Map<String, dynamic>> rows) => rows
    .where((item) => (item['status']?.toString() ?? '') == 'Paid')
    .fold<double>(0.0, (sum, item) => sum + OrgAdminApi.asDouble(item['amount']));

int _ledgerPendingCount(List<Map<String, dynamic>> rows) =>
    rows.where((item) => (item['status']?.toString() ?? '') == 'Pending').length;

String _formatLedgerIls(double amount) {
  final formatted =
      amount.truncateToDouble() == amount ? amount.toInt().toString() : amount.toStringAsFixed(2);
  return '$formatted ILS';
}

List<Map<String, dynamic>> _buildAdminPaymentHistoryList() {
  return _kDefaultAdminPaymentHistory()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

/// Parsed billing snapshot for admin ledger + payroll.
class _BillingSnapshot {
  const _BillingSnapshot({
    required this.ledger,
    required this.doctors,
  });

  final List<Map<String, dynamic>> ledger;
  final List<Map<String, dynamic>> doctors;
}

class _AdminBillingError extends StatelessWidget {
  const _AdminBillingError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent.shade200, size: 48),
            const SizedBox(height: 16),
            Text(
              'Billing data unavailable',
              style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(color: Colors.white60, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 8 Invoicing & billing ledger + payroll
class OrgAdminBillingTab extends StatefulWidget {
  const OrgAdminBillingTab({super.key, required this.api});
  final OrgAdminApi api;
  @override
  State<OrgAdminBillingTab> createState() => _OrgAdminBillingTabState();
}

class _OrgAdminBillingTabState extends State<OrgAdminBillingTab> {
  List<Map<String, dynamic>> _paymentHistoryList = _buildAdminPaymentHistoryList();
  List<Map<String, dynamic>> _doctors = List.from(_kDefaultAdminDoctors());
  String? _selectedDoctorId;
  Map<String, dynamic>? _payrollPreview;
  Map<String, dynamic>? _lastSlip;
  bool _payrollBusy = false;

  static const double _kPresentationCommissionRate = 0.2;

  @override
  void initState() {
    super.initState();
    _loadDoctorsOptional();
  }

  void _refreshBilling() {
    setState(() {
      _paymentHistoryList = _buildAdminPaymentHistoryList();
    });
    _loadDoctorsOptional();
  }

  Future<void> _loadDoctorsOptional() async {
    try {
      final doctors = await widget.api.getJson('/doctors');
      final parsed = OrgAdminApi.asMapList(doctors);
      if (!mounted) return;
      setState(() {
        _doctors = parsed.isNotEmpty ? parsed : List.from(_kDefaultAdminDoctors());
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _doctors = List.from(_kDefaultAdminDoctors());
      });
    }
  }

  Future<void> _previewPayroll() async {
    if (_selectedDoctorId == null) return;

    Map<String, dynamic>? doctor;
    for (final d in _doctors) {
      final id = d['_id']?.toString() ?? d['userId']?.toString();
      if (id == _selectedDoctorId) {
        doctor = d;
        break;
      }
    }

    final grossEarned = _ledgerPaidAmountSum(_paymentHistoryList);
    final clinicShare = grossEarned * _kPresentationCommissionRate;
    final netPayout = grossEarned - clinicShare;

    if (mounted) {
      setState(() {
        _payrollPreview = {
          'doctorName':
              doctor?['name']?.toString() ?? doctor?['displayName']?.toString() ?? 'doctor',
          'grossEarned': grossEarned,
          'clinicShare': clinicShare,
          'pharmacyRevenue': 0,
          'netPayout': netPayout,
        };
      });
    }
  }

  Future<void> _generatePayroll() async {
    if (_selectedDoctorId == null) return;
    setState(() => _payrollBusy = true);
    try {
      final slip = await widget.api.postJsonMap('/billing/payroll/generate', {'doctorUserId': _selectedDoctorId});
      if (!mounted) return;
      setState(() {
        _lastSlip = slip;
        _payrollPreview = null;
      });
      _refreshBilling();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payroll slip generated — unsettled consultations marked settled.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _payrollBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildBillingContent(
      _BillingSnapshot(
        ledger: _paymentHistoryList,
        doctors: _doctors,
      ),
    );
  }

  Widget _buildBillingContent(_BillingSnapshot data) {
    const currency = 'ILS';
    final ledger = data.ledger;
    final doctors = data.doctors;
    final commissionPct = (_kPresentationCommissionRate * 100).toStringAsFixed(0);

    final totalRevenue = _ledgerAmountSum(ledger);
    final paidRevenue = _ledgerPaidAmountSum(ledger);
    final transactionCount = ledger.length;
    final pendingCount = _ledgerPendingCount(ledger);

    return OrgAdminScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _title('Facility billing ledger')),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refreshBilling,
                icon: const Icon(Icons.refresh, color: _kGold),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatCard('Monthly revenue', _formatLedgerIls(totalRevenue)),
              _StatCard('Transactions', '$transactionCount'),
              _StatCard('All-time paid', _formatLedgerIls(paidRevenue)),
              _StatCard('Pending', '$pendingCount'),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: _kGlass,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _kGold.withValues(alpha: 0.45)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.black26),
                columns: const [
                  DataColumn(label: Text('Transaction ID', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Patient', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Service', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Amount', style: TextStyle(color: _kGold, fontWeight: FontWeight.bold))),
                ],
                rows: ledger.map((row) {
                        final status = row['status']?.toString() ?? 'Paid';
                        final service = row['serviceType']?.toString() ?? row['type']?.toString() ?? 'Other';
                        final amount = OrgAdminApi.asDouble(row['amount']);
                        final amountText = amount.truncateToDouble() == amount
                            ? '${amount.toInt()} $currency'
                            : '${amount.toStringAsFixed(2)} $currency';
                        return DataRow(cells: [
                          DataCell(Text(
                            row['transactionId']?.toString() ?? row['id']?.toString() ?? '—',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          )),
                          DataCell(Text(row['patientName']?.toString() ?? '—', style: const TextStyle(color: Colors.white))),
                          DataCell(Text(service, style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(status, style: TextStyle(color: status == 'Paid' ? Colors.greenAccent : _kGoldLight))),
                          DataCell(Text(amountText, style: const TextStyle(color: _kGoldLight, fontWeight: FontWeight.w600))),
                        ]);
                      }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _title('Monthly doctor payroll'),
          const SizedBox(height: 8),
          Text(
            'Net payout = consultation revenue minus clinic commission ($commissionPct%), plus attributed pharmacy sales.',
            style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedDoctorId,
            dropdownColor: const Color(0xFF1A1A18),
            decoration: InputDecoration(
              labelText: 'Select doctor',
              labelStyle: GoogleFonts.urbanist(color: _kGold),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _kGold.withValues(alpha: 0.45))),
            ),
            items: doctors
                .map((d) {
                  final id = d['_id']?.toString() ?? d['userId']?.toString();
                  if (id == null || id.isEmpty) return null;
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(
                      d['name']?.toString() ?? d['displayName']?.toString() ?? d['fullName']?.toString() ?? 'Doctor',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                })
                .whereType<DropdownMenuItem<String>>()
                .toList(),
            onChanged: (v) => setState(() {
              _selectedDoctorId = v;
              _payrollPreview = null;
              _lastSlip = null;
            }),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: _kGoldLight, side: BorderSide(color: _kGold.withValues(alpha: 0.55))),
                onPressed: _selectedDoctorId == null ? null : _previewPayroll,
                child: const Text('Preview payout'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
                onPressed: _payrollBusy || _selectedDoctorId == null ? null : _generatePayroll,
                child: _payrollBusy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Generate Payroll Slip'),
              ),
            ],
          ),
          if (_payrollPreview != null) ...[
            const SizedBox(height: 16),
            _PayrollSlipCard(data: _payrollPreview!, currency: currency, title: 'Payroll preview'),
          ],
          if (_lastSlip != null) ...[
            const SizedBox(height: 16),
            _PayrollSlipCard(data: _lastSlip!, currency: currency, title: 'Generated payslip (audit record)'),
          ],
        ],
      ),
    );
  }
}

class _PayrollSlipCard extends StatelessWidget {
  const _PayrollSlipCard({required this.data, required this.currency, required this.title});

  final Map<String, dynamic> data;
  final String currency;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _kGlass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _kGold.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(data['doctorName']?.toString() ?? 'Doctor', style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w600)),
            const Divider(color: Colors.white12),
            _payRow('Total generated revenue', data['grossEarned'], currency),
            _payRow('Clinic commission share deducted', data['clinicShare'], currency),
            if ((OrgAdminApi.asDouble(data['pharmacyRevenue']) > 0))
              _payRow('Pharmacy sales contribution', data['pharmacyRevenue'], currency),
            const SizedBox(height: 6),
            _payRow('Final net profit', data['netPayout'], currency, highlight: true),
          ],
        ),
      ),
    );
  }

  Widget _payRow(String label, dynamic amount, String currency, {bool highlight = false}) {
    final value = OrgAdminApi.asDouble(amount);
    final formatted = value.truncateToDouble() == value ? value.toInt().toString() : value.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.urbanist(color: Colors.white70)),
          Text(
            '$formatted $currency',
            style: GoogleFonts.urbanist(
              color: highlight ? _kGoldLight : Colors.white,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// System config
class OrgAdminSettingsTab extends StatefulWidget {
  const OrgAdminSettingsTab({super.key, required this.api});
  final OrgAdminApi api;
  @override
  State<OrgAdminSettingsTab> createState() => _OrgAdminSettingsTabState();
}

class _OrgAdminSettingsTabState extends State<OrgAdminSettingsTab> {
  final _currency = TextEditingController(text: 'ILS');
  final _penalty = TextEditingController();
  final _locale = TextEditingController();

  @override
  void dispose() {
    _currency.dispose();
    _penalty.dispose();
    _locale.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.api.getJson('/system-config').then((r) {
      final s = (r as Map)['adminSettings'] as Map? ?? {};
      _currency.text = '${s['defaultCurrency'] ?? 'ILS'}';
      _penalty.text = '${s['cancellationPenaltyPolicy'] ?? ''}';
      _locale.text = '${s['locale'] ?? 'en'}';
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return OrgAdminScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('System configuration'),
          TextField(controller: _currency, style: const TextStyle(color: Colors.white), decoration: _dec('Default currency')),
          TextField(controller: _locale, style: const TextStyle(color: Colors.white), decoration: _dec('Locale (en/ar)')),
          TextField(controller: _penalty, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: _dec('Cancellation penalty policy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
            onPressed: () async {
              await widget.api.patchJson('/system-config', {
                'adminSettings': {
                  'defaultCurrency': _currency.text.trim(),
                  'locale': _locale.text.trim(),
                  'cancellationPenaltyPolicy': _penalty.text.trim(),
                },
              });
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
            },
            child: const Text('Save configuration'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Backup request logged â€” implement server export hook as needed.')),
            ),
            style: OutlinedButton.styleFrom(foregroundColor: _kGold, side: const BorderSide(color: _kGold)),
            child: const Text('Request database backup'),
          ),
        ],
      ),
    );
  }
}
