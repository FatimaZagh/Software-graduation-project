import 'dart:async';

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/rafeeq_language_toggle.dart';

import 'patient_home_screen.dart';
import 'patient_theme.dart';
import '../../../login_screen.dart';
import '../../../patient_portal_screens.dart';
import 'patient_payment_history_screen.dart';
import 'patient_medical_records_screen.dart';
import 'patient_booking_pharmacy_health.dart';
import 'patient_more_features.dart';
import '../data/patient_portal_api.dart';
import '../data/patient_navigation_bus.dart';
import 'patient_home_video_bridge.dart';
import '../../../utils/chat_notification_helpers.dart';
import '../../../tenant_state.dart';

/// Main responsive patient shell: bottom navigation + drawer + localized labels.
class PatientDashboardShell extends StatefulWidget {
  final String patientUserId;

  const PatientDashboardShell({super.key, required this.patientUserId});

  @override
  State<PatientDashboardShell> createState() => _PatientDashboardShellState();
}

class _PatientDashboardShellState extends State<PatientDashboardShell> {
  static const int _pharmacyTabIndex = 2;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  Timer? _poll;
  int _unreadNotifs = 0;
  bool _hasUnreadMessages = false;

  @override
  void initState() {
    super.initState();
    PatientNavigationBus.pending.addListener(_onNavigationIntent);
    _refreshNotifications();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _refreshNotifications(silent: true));
  }

  @override
  void dispose() {
    PatientNavigationBus.pending.removeListener(_onNavigationIntent);
    _poll?.cancel();
    super.dispose();
  }

  void _onNavigationIntent() {
    final intent = PatientNavigationBus.pending.value;
    if (intent == null || !intent.isPharmacyDeepLink) return;
    if (_index != _pharmacyTabIndex) {
      setState(() => _index = _pharmacyTabIndex);
    }
    if (intent.notificationId != null && intent.notificationId!.isNotEmpty) {
      _refreshNotifications(silent: true);
    }
  }

  Future<void> _refreshNotifications({bool silent = false}) async {
    try {
      final list = await PatientPortalApi.getNotifications(widget.patientUserId);
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

  Future<T?> _withPausedHomeVideo<T>(Future<T?> Function() action) {
    return PatientHomeVideoBridge.instance.runWithPausedOverlay(action);
  }

  Widget _messageButton() {
    return IconButton(
      tooltip: 'Messages',
      onPressed: () async {
        await _withPausedHomeVideo(() {
          return Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PatientDoctorChatScreen(patientUserId: widget.patientUserId),
            ),
          );
        });
        _refreshNotifications();
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.chat_bubble_outline),
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
    );
  }

  Widget _bellButton() {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () async {
        await _withPausedHomeVideo(() {
          return Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => PatientNotificationsScreen(patientUserId: widget.patientUserId)),
          );
        });
        _refreshNotifications();
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
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
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tenant = TenantState.instance;
    const themeBg = kPatientWorkspaceBlack;

    // Fixed 5-tab patient shell: Home, Book, Pharmacy, Health, More (index 0–4).
    final titles = <String>[
      l10n.navHome,
      l10n.navBook,
      l10n.navPharmacy,
      l10n.navHealth,
      l10n.navMore,
    ];

    final bodies = <Widget>[
      PatientHomeScreen(patientUserId: widget.patientUserId, embedMode: true),
      PatientBookingTab(patientUserId: widget.patientUserId),
      PatientPharmacyTab(
        patientUserId: widget.patientUserId,
        isTabActive: _index == _pharmacyTabIndex,
      ),
      PatientHealthDigitalTab(patientUserId: widget.patientUserId),
      PatientMoreHub(patientUserId: widget.patientUserId),
    ];

    final safeIndex = _index.clamp(0, bodies.length - 1);
    final homeVideoBackground = safeIndex == 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: homeVideoBackground ? Colors.transparent : themeBg,
      extendBodyBehindAppBar: homeVideoBackground,
      appBar: AppBar(
        backgroundColor: homeVideoBackground ? Colors.transparent : kPatientWorkspaceBlack,
        foregroundColor: kPatientGoldLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: kPatientGold),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(titles[safeIndex], style: const TextStyle(color: kPatientGold, fontWeight: FontWeight.w700)),
        actions: [
          _messageButton(),
          _bellButton(),
          RafeeqLanguageToggle(iconColor: kPatientGoldLight),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: kPatientFieldFill,
                  border: Border(bottom: BorderSide(color: kPatientGold, width: 1)),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    tenant.theme.name.isNotEmpty ? tenant.theme.name : l10n.appTitle,
                    style: const TextStyle(color: kPatientGoldLight, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.home_outlined),
                title: Text(l10n.navHome),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _index = 0);
                },
              ),
              ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text(l10n.profileSettings),
                onTap: () async {
                  Navigator.pop(context);
                  await _withPausedHomeVideo(() {
                    return Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileSettingsScreen(patientUserId: widget.patientUserId),
                      ),
                    );
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.folder_open_outlined),
                title: Text(l10n.medicalRecords),
                onTap: () async {
                  Navigator.pop(context);
                  await _withPausedHomeVideo(() {
                    return Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientMedicalRecordsScreen(patientUserId: widget.patientUserId),
                      ),
                    );
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.payment_outlined),
                title: Text(l10n.paymentHistory),
                onTap: () async {
                  Navigator.pop(context);
                  await _withPausedHomeVideo(() {
                    return Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientPaymentHistoryScreen(patientUserId: widget.patientUserId),
                      ),
                    );
                  });
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red.shade700),
                title: Text(l10n.logout),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => LoginScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          return IndexedStack(
            index: safeIndex,
            children: bodies,
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: kPatientFieldFill,
        indicatorColor: kPatientGold.withValues(alpha: 0.25),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l10n.navHome),
          NavigationDestination(icon: const Icon(Icons.event_available_outlined), label: l10n.navBook),
          NavigationDestination(icon: const Icon(Icons.local_pharmacy_outlined), label: l10n.navPharmacy),
          NavigationDestination(icon: const Icon(Icons.favorite_outline), label: l10n.navHealth),
          NavigationDestination(icon: const Icon(Icons.grid_view), label: l10n.navMore),
        ],
      ),
    );
  }
}
