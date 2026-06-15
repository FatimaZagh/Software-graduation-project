import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../utils/chat_notification_helpers.dart';
import '../../../landing_screen.dart';
import '../../../tenant_state.dart';
import '../../../widgets/rafeeq_language_toggle.dart';
import '../data/doctor_portal_api.dart';
import '../data/doctor_session.dart';
import '../data/doctor_workspace_api.dart';
import '../../diagnostic/data/diagnostic_api.dart';
import '../../diagnostic/presentation/doctor_diagnostic_results_screen.dart';
import '../../leave/leave_navigation.dart';
import 'doctor_chats_screen.dart';
import 'doctor_notifications_screen.dart';
import 'doctor_patients_screen.dart';
import 'doctor_profile_screen.dart';
import 'doctor_tab_pages.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kSidebar = Color(0xF00A1412);
const double _kBreakpoint = 900;

/// Doctor clinical workspace — dark/gold premium UI, 3 main tabs, RBAC via `/api/doctor`.
class DoctorDashboardShell extends StatefulWidget {
  const DoctorDashboardShell({super.key, required this.doctorUserId, this.doctorName});

  final String doctorUserId;
  final String? doctorName;

  @override
  State<DoctorDashboardShell> createState() => _DoctorDashboardShellState();
}

class _DoctorDashboardShellState extends State<DoctorDashboardShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  late final DoctorWorkspaceApi _api;
  String _specialty = 'General Practice';
  bool _hasUnreadMessages = true; // mock/testing — toggle red badge visibility
  int _unreadNotifs = 0;
  int _unreadLab = 0;
  int _unreadRadiology = 0;
  Timer? _notifPoll;

  static const _nav = <({IconData icon, String labelKey})>[
    (icon: Icons.dashboard_customize_outlined, labelKey: 'dashboard'),
    (icon: Icons.folder_shared_outlined, labelKey: 'patients'),
    (icon: Icons.event_note_outlined, labelKey: 'appointments'),
  ];

  @override
  void initState() {
    super.initState();
    DoctorSession.instance.load();
    _api = DoctorWorkspaceApi(doctorUserId: widget.doctorUserId);
    _loadProfile();
    _refreshNotifications();
    _refreshDiagnosticBadges();
    _notifPoll = Timer.periodic(const Duration(seconds: 8), (_) {
      _refreshNotifications(silent: true);
      _refreshDiagnosticBadges(silent: true);
    });
  }

  @override
  void dispose() {
    _notifPoll?.cancel();
    super.dispose();
  }

  Future<void> _refreshNotifications({bool silent = false}) async {
    try {
      final list = await DoctorPortalApi.getNotifications(widget.doctorUserId);
      final unread = list.where((e) => e is Map && e['read'] != true).length;
      final unreadMessages = list.where((e) {
        if (e is! Map) return false;
        final m = Map<String, dynamic>.from(e);
        return m['read'] != true && ChatNotificationHelpers.isMessageNotification(m);
      }).length;
      if (!mounted) return;
      setState(() {
        _unreadNotifs = unread;
        _hasUnreadMessages = unreadMessages > 0;
      });
    } catch (_) {
      if (!silent) {}
    }
  }

  Future<void> _refreshDiagnosticBadges({bool silent = false}) async {
    try {
      final counts = await DiagnosticApi(userId: widget.doctorUserId).unreadCounts();
      if (!mounted) return;
      setState(() {
        _unreadLab = (counts['labUnread'] as num?)?.toInt() ?? 0;
        _unreadRadiology = (counts['radiologyUnread'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      if (!silent) {}
    }
  }

  void _openDiagnosticResults(DiagnosticResultsKind kind) {
    setState(() {
      if (kind == DiagnosticResultsKind.lab) {
        _unreadLab = 0;
      } else {
        _unreadRadiology = 0;
      }
    });
    if (MediaQuery.sizeOf(context).width < _kBreakpoint) Navigator.pop(context);
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DoctorDiagnosticResultsScreen(
          doctorUserId: widget.doctorUserId,
          kind: kind,
        ),
      ),
    ).then((_) => _refreshDiagnosticBadges());
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _api.profile();
      if (!mounted) return;
      setState(() {
        _specialty = p['specialty']?.toString() ?? p['specialization']?.toString() ?? 'General Practice';
      });
    } catch (_) {}
  }

  void _onFeatureSelected(String key) {
    switch (key) {
      case 'appointments':
      case 'waiting_list':
      case 'my_schedule':
        setState(() => _index = 2);
        break;
      case 'patient_records':
      case 'e_prescription':
      case 'order_lab':
      case 'order_imaging':
        setState(() => _index = 1);
        break;
      case 'incoming_messages':
        if (MediaQuery.sizeOf(context).width < _kBreakpoint) Navigator.pop(context);
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => DoctorChatsScreen(api: _api)),
        ).then((_) => _refreshNotifications());
        break;
      case 'notifications':
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => DoctorNotificationsScreen(api: _api)),
        ).then((_) => _refreshNotifications());
        break;
      case 'clinic_analytics':
        setState(() => _index = 0);
        break;
      default:
        break;
    }
  }

  List<Widget> get _pages => [
        DoctorHomeTab(api: _api, onFeatureSelected: _onFeatureSelected),
        DoctorPatientsTab(api: _api, specialty: _specialty),
        DoctorAppointmentsTab(api: _api, specialty: _specialty),
      ];

  int get _safeIndex => _index < _nav.length ? _index : 0;

  Future<void> _logout() async {
    await DoctorSession.instance.clear();
    TenantState.instance.clear();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => const LandingScreen()));
  }

  String _navLabel(String key, S l10n) {
    switch (key) {
      case 'dashboard':
        return l10n.doctorGridDashboard;
      case 'patients':
        return l10n.doctorGridPatients;
      case 'appointments':
        return l10n.doctorGridAppointments;
      default:
        return key;
    }
  }

  Widget _navTile(int i, S l10n) {
    final sel = _index == i;
    return Material(
      color: sel ? _kGold.withValues(alpha: 0.14) : Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(_nav[i].icon, color: sel ? _kGold : Colors.white54),
        title: Text(
          _navLabel(_nav[i].labelKey, l10n),
          style: GoogleFonts.urbanist(
            color: sel ? _kGoldLight : Colors.white70,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        selected: sel,
        onTap: () {
          setState(() => _index = i);
          if (MediaQuery.sizeOf(context).width < _kBreakpoint) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _messagesTile(S l10n) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.chat_bubble_outline, color: Colors.white54),
            if (_hasUnreadMessages)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
        title: Text(l10n.doctorGridIncomingMessages, style: GoogleFonts.urbanist(color: Colors.white70)),
        onTap: () => _onFeatureSelected('incoming_messages'),
      ),
    );
  }

  Widget _sidebarTileWithBadge({
    required IconData icon,
    required String label,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: Colors.white54),
            if (badgeCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
        title: Text(label, style: GoogleFonts.urbanist(color: Colors.white70)),
        onTap: onTap,
      ),
    );
  }

  Widget _sidebarFooterTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = _kGoldLight,
  }) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(label, style: GoogleFonts.urbanist(color: Colors.white70)),
        onTap: onTap,
      ),
    );
  }

  Widget _sidebar({required bool extended, required S l10n}) {
    return Material(
      color: _kSidebar,
      elevation: 0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rafeeq', style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 22, fontWeight: FontWeight.w700)),
                  Text(widget.doctorName ?? 'Doctor', style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 13)),
                  Text(_specialty, style: GoogleFonts.urbanist(color: _kGold.withValues(alpha: 0.8), fontSize: 11)),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView(
                children: [
                  _navTile(0, l10n),
                  _navTile(1, l10n),
                  _messagesTile(l10n),
                  _navTile(2, l10n),
                  _sidebarTileWithBadge(
                    icon: Icons.biotech_outlined,
                    label: l10n.doctorGridLabResults,
                    badgeCount: _unreadLab,
                    onTap: () => _openDiagnosticResults(DiagnosticResultsKind.lab),
                  ),
                  _sidebarTileWithBadge(
                    icon: Icons.monitor_heart_outlined,
                    label: l10n.doctorGridRadiologyResults,
                    badgeCount: _unreadRadiology,
                    onTap: () => _openDiagnosticResults(DiagnosticResultsKind.radiology),
                  ),
                ],
              ),
            ),
            _sidebarFooterTile(
              icon: Icons.time_to_leave_outlined,
              label: leaveRequestsNavLabel(context),
              onTap: () {
                if (MediaQuery.sizeOf(context).width < _kBreakpoint) Navigator.pop(context);
                openLeaveRequestScreen(context, userId: widget.doctorUserId);
              },
            ),
            _sidebarFooterTile(
              icon: Icons.people_outline,
              label: l10n.doctorGridMyPatients,
              onTap: () {
                if (MediaQuery.sizeOf(context).width < _kBreakpoint) Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DoctorPatientsScreen(api: _api),
                  ),
                );
              },
            ),
            _sidebarFooterTile(
              icon: Icons.person_outline,
              label: l10n.doctorGridProfile,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DoctorProfileScreen(doctorUserId: widget.doctorUserId),
                  ),
                );
              },
            ),
            _sidebarFooterTile(
              icon: Icons.logout,
              label: l10n.logOut,
              iconColor: Colors.redAccent,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= _kBreakpoint;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      drawer: wide ? null : Drawer(child: _sidebar(extended: true, l10n: l10n)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A0F0D), Color(0xFF1A1510), Color(0xFF0D1210)],
              ),
            ),
          ),
          Row(
            children: [
              if (wide) SizedBox(width: 240, child: _sidebar(extended: true, l10n: l10n)),
              Expanded(
                child: Column(
                  children: [
                    Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            if (!wide)
                              IconButton(
                                icon: const Icon(Icons.menu, color: _kGoldLight),
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                              ),
                            Text(
                              _navLabel(_nav[_safeIndex].labelKey, l10n),
                              style: GoogleFonts.urbanist(color: _kGold, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            const RafeeqLanguageToggle(iconColor: _kGoldLight),
                            IconButton(
                              tooltip: l10n.notifications,
                              onPressed: () => _onFeatureSelected('notifications'),
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.notifications_none, color: _kGoldLight),
                                  if (_unreadNotifs > 0)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade700,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _unreadNotifs > 99 ? '99+' : '$_unreadNotifs',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.doctorGridIncomingMessages,
                              onPressed: () => _onFeatureSelected('incoming_messages'),
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.chat_bubble_outline, color: _kGoldLight),
                                  if (_hasUnreadMessages)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: _pages[_safeIndex],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
