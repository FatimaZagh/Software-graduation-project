import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../tenant_state.dart';
import '../../../widgets/rafeeq_back_home_button.dart';
import '../../../widgets/rafeeq_language_toggle.dart';
import '../data/org_admin_api.dart';
import '../data/org_admin_session.dart';
import 'org_admin_tab_pages.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kSidebar = Color(0xF00A1412);
const double _kSidebarBreakpoint = 900;

/// Clinic / organization admin shell — no back navigation to public site.
class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key, required this.adminUserId, this.adminName});

  final String adminUserId;
  final String? adminName;

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  late final OrgAdminApi _api;

  static const _nav = <({IconData icon, String labelKey})>[
    (icon: Icons.dashboard_outlined, labelKey: 'adminNavDashboard'),
    (icon: Icons.analytics_outlined, labelKey: 'adminNavDoctorAnalytics'),
    (icon: Icons.badge_outlined, labelKey: 'adminNavStaff'),
    (icon: Icons.people_outline, labelKey: 'adminNavPatients'),
    (icon: Icons.event_note_outlined, labelKey: 'adminNavAppointments'),
    (icon: Icons.beach_access_outlined, labelKey: 'adminNavLeave'),
    (icon: Icons.receipt_long_outlined, labelKey: 'adminNavBilling'),
    (icon: Icons.settings_outlined, labelKey: 'adminNavSettings'),
  ];

  @override
  void initState() {
    super.initState();
    OrgAdminSession.instance.load();
    _api = OrgAdminApi(adminUserId: widget.adminUserId);
  }

  String _navLabel(BuildContext context, String labelKey) {
    final l10n = context.l10n;
    return switch (labelKey) {
      'adminNavDashboard' => l10n.adminNavDashboard,
      'adminNavDoctorAnalytics' => l10n.adminNavDoctorAnalytics,
      'adminNavStaff' => l10n.adminNavStaff,
      'adminNavPatients' => l10n.adminNavPatients,
      'adminNavAppointments' => l10n.adminNavAppointments,
      'adminNavLeave' => l10n.adminNavLeave,
      'adminNavBilling' => l10n.adminNavBilling,
      'adminNavSettings' => l10n.adminNavSettings,
      _ => labelKey,
    };
  }

  List<Widget> get _pages => [
        OrgAdminDashboardTab(api: _api),
        OrgAdminDoctorAnalyticsTab(api: _api),
        OrgAdminStaffTab(api: _api),
        OrgAdminPatientsTab(api: _api),
        OrgAdminAppointmentsTab(api: _api),
        OrgAdminLeaveTab(api: _api),
        OrgAdminBillingTab(api: _api),
        OrgAdminSettingsTab(api: _api),
      ];

  Future<void> _logout() async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logoutDialogTitle),
        content: Text(l10n.logoutDialogReturnToLandingAdmin),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.logOut)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await OrgAdminSession.instance.clear();
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
            if (_scaffoldKey.currentState?.isDrawerOpen == true) {
              Navigator.pop(context);
            }
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
                      style: GoogleFonts.poppins(
                        color: selected ? _kGold : Colors.white.withValues(alpha: 0.88),
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
    final facility = TenantState.instance.theme.name;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: compact ? 72 : 260,
          decoration: BoxDecoration(
            color: _kSidebar,
            border: Border(right: BorderSide(color: _kGold.withValues(alpha: 0.35))),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.apartment_rounded, color: _kGold, size: compact ? 28 : 32),
                      if (!compact) ...[
                        const SizedBox(height: 8),
                        Text(
                          facility.isEmpty ? l10n.adminClinicAdmin : facility,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          widget.adminName ?? l10n.adminAdministrator,
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _nav.length,
                    itemBuilder: (_, i) => _sidebarTile(context, i, compact),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, size: 20),
                      label: compact ? const SizedBox.shrink() : Text(l10n.logOut),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGold,
                        side: const BorderSide(color: _kGold),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
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
    final wide = MediaQuery.sizeOf(context).width >= _kSidebarBreakpoint;
    final title = _navLabel(context, _nav[_index.clamp(0, _nav.length - 1)].labelKey);

    return PopScope(
      canPop: false,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF06100E),
        drawer: wide
            ? null
            : Drawer(
                backgroundColor: Colors.transparent,
                child: _buildSidebar(context, compact: false),
              ),
        appBar: AppBar(
          backgroundColor: const Color(0xCC0A1412),
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: wide
              ? null
              : IconButton(
                  icon: const Icon(Icons.menu, color: _kGold),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
          title: Text(
            title,
            style: GoogleFonts.playfairDisplay(color: _kGold, fontWeight: FontWeight.w600, fontSize: 20),
          ),
          actions: [
            const RafeeqLanguageToggle(iconColor: _kGold),
            if (!wide)
              TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: _kGold, size: 20),
                label: Text(l10n.logOut, style: const TextStyle(color: _kGold)),
              ),
          ],
        ),
        body: Row(
          children: [
            if (wide) _buildSidebar(context, compact: false),
            Expanded(
              child: Material(
                color: const Color(0xFF0D1A17),
                child: IndexedStack(
                  index: _index.clamp(0, _pages.length - 1),
                  children: _pages,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index.clamp(0, 4),
                onDestinationSelected: (i) => setState(() => _index = i),
                backgroundColor: const Color(0xCC0A1412),
                indicatorColor: _kGold.withValues(alpha: 0.25),
                destinations: _nav
                    .take(5)
                    .map(
                      (n) => NavigationDestination(
                        icon: Icon(n.icon),
                        label: _navLabel(context, n.labelKey).split(' ').first,
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}
