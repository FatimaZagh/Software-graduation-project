import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../tenant_state.dart';
import '../../../widgets/rafeeq_back_home_button.dart';
import '../../../widgets/rafeeq_language_toggle.dart';
import '../data/nurse_portal_api.dart';
import '../data/nurse_session.dart';
import '../../leave/leave_navigation.dart';
import 'nurse_tab_pages.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kSidebar = Color(0xF00A1412);
const double _kBreakpoint = 900;

/// Clinical nurse workspace — RBAC-limited nav (no billing/staff/admin).
class NurseDashboardShell extends StatefulWidget {
  const NurseDashboardShell({super.key, required this.nurseUserId, this.nurseName});

  final String nurseUserId;
  final String? nurseName;

  @override
  State<NurseDashboardShell> createState() => _NurseDashboardShellState();
}

class _NurseDashboardShellState extends State<NurseDashboardShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  late final NursePortalApi _api;
  String? _selectedPatientId;
  String _selectedPatientLabel = '';

  static const _nav = <({IconData icon, String labelKey})>[
    (icon: Icons.people_outline, labelKey: 'nurseNavPatients'),
    (icon: Icons.queue_play_next, labelKey: 'nurseNavTriageQueue'),
    (icon: Icons.monitor_heart_outlined, labelKey: 'nurseNavVitals'),
    (icon: Icons.note_alt_outlined, labelKey: 'nurseNavNursingNotes'),
    (icon: Icons.medication_outlined, labelKey: 'nurseNavMedications'),
    (icon: Icons.biotech_outlined, labelKey: 'nurseNavLabs'),
    (icon: Icons.notifications_active_outlined, labelKey: 'nurseNavAlerts'),
    (icon: Icons.badge_outlined, labelKey: 'nurseNavProfileHr'),
  ];

  @override
  void initState() {
    super.initState();
    _api = NursePortalApi(nurseUserId: widget.nurseUserId);
  }

  String _navLabel(BuildContext context, String labelKey) {
    final l10n = context.l10n;
    return switch (labelKey) {
      'nurseNavPatients' => l10n.nurseNavPatients,
      'nurseNavTriageQueue' => l10n.nurseNavTriageQueue,
      'nurseNavVitals' => l10n.nurseNavVitals,
      'nurseNavNursingNotes' => l10n.nurseNavNursingNotes,
      'nurseNavMedications' => l10n.nurseNavMedications,
      'nurseNavLabs' => l10n.nurseNavLabs,
      'nurseNavAlerts' => l10n.nurseNavAlerts,
      'nurseNavProfileHr' => l10n.nurseNavProfileHr,
      _ => labelKey,
    };
  }

  void _selectPatient(String? id, String label) {
    setState(() {
      _selectedPatientId = id;
      _selectedPatientLabel = label;
    });
  }

  List<Widget> get _pages => [
        NursePatientsTab(api: _api, onSelectPatient: _selectPatient),
        NurseTriageTab(api: _api, onSelectPatient: _selectPatient),
        NurseVitalsTab(api: _api, patientId: _selectedPatientId, patientLabel: _selectedPatientLabel),
        NurseNotesTab(api: _api, patientId: _selectedPatientId, patientLabel: _selectedPatientLabel),
        NurseMedicationsTab(api: _api, patientId: _selectedPatientId, patientLabel: _selectedPatientLabel),
        NurseLabsTab(api: _api, patientId: _selectedPatientId, patientLabel: _selectedPatientLabel),
        NurseAlertsTab(api: _api, patientId: _selectedPatientId, patientLabel: _selectedPatientLabel),
        NurseProfileTab(api: _api, nurseUserId: widget.nurseUserId, nurseName: widget.nurseName),
      ];

  /// Only mount the active tab — avoids hidden tabs firing restricted API calls on load.
  Widget _activePage() {
    final i = _index.clamp(0, _pages.length - 1);
    return _pages[i];
  }

  Future<void> _logout() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logoutDialogTitle),
        content: Text(l10n.logoutDialogReturnToLanding),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.logOut)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await NurseSession.instance.clear();
    TenantState.instance.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tenant.orgId');
    await prefs.remove('tenant.preferredClinicId');
    if (!mounted) return;
    rafeeqNavigateBackToHome(context);
  }

  Widget _sidebarTile(BuildContext context, int i, bool compact) {
    final selected = _index == i;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? _kGold.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() => _index = i);
            if (_scaffoldKey.currentState?.isDrawerOpen == true) Navigator.pop(context);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 12),
            child: Row(
              children: [
                Icon(_nav[i].icon, color: selected ? _kGold : Colors.white70, size: 22),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _navLabel(context, _nav[i].labelKey),
                      style: TextStyle(
                        color: selected ? _kGold : Colors.white70,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, {required bool compact}) {
    final l10n = context.l10n;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: compact ? 72 : 240,
          decoration: const BoxDecoration(
            color: _kSidebar,
            border: Border(right: BorderSide(color: _kGold, width: 1)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: compact
                      ? const Icon(Icons.local_hospital, color: _kGold, size: 28)
                      : Text(
                          l10n.nurseStationTitle,
                          style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                ),
                if (!compact && _selectedPatientLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      l10n.nurseActivePatient(_selectedPatientLabel),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _nav.length,
                    itemBuilder: (_, i) => _sidebarTile(context, i, compact),
                  ),
                ),
                if (!compact)
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.time_to_leave_outlined, color: _kGold),
                      title: Text(
                        leaveRequestsNavLabel(context),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      onTap: () {
                        if (_scaffoldKey.currentState?.isDrawerOpen == true) Navigator.pop(context);
                        openLeaveRequestScreen(context, userId: widget.nurseUserId);
                      },
                    ),
                  ),
                if (!compact)
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: Text(l10n.logOut, style: const TextStyle(color: Colors.redAccent)),
                      onTap: _logout,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= _kBreakpoint;

    return PopScope(
      canPop: false,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF0A1412),
        drawer: wide
            ? null
            : Drawer(
                backgroundColor: Colors.transparent,
                child: _buildSidebar(context, compact: false),
              ),
        appBar: AppBar(
          backgroundColor: const Color(0xE6101A18),
          foregroundColor: _kGold,
          title: Text(l10n.nurseStationTitle, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
          leading: wide
              ? null
              : IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
          actions: [
            const RafeeqLanguageToggle(iconColor: _kGold),
            if (!wide) IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: wide
            ? Row(
                children: [
                  _buildSidebar(context, compact: false),
                  Expanded(child: _activePage()),
                ],
              )
            : _activePage(),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index.clamp(0, 4),
                onDestinationSelected: (i) => setState(() => _index = i),
                backgroundColor: const Color(0xFF101A18),
                indicatorColor: _kGold.withValues(alpha: 0.25),
                destinations: _nav
                    .take(5)
                    .map(
                      (n) => NavigationDestination(
                        icon: Icon(n.icon),
                        label: _navLabel(context, n.labelKey),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}
