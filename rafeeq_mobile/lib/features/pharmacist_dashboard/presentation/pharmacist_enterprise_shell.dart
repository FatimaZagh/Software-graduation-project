import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../widgets/rafeeq_language_toggle.dart';
import '../data/pharmacist_session.dart';
import '../data/pharmacy_inventory_api.dart';
import 'pharmacist_logout.dart';
import 'pharmacist_module_pages.dart';
import 'pharmacist_theme.dart';

/// All-in-One Pharmacy Enterprise Management Suite — sidebar + dynamic content.
class PharmacistEnterpriseShell extends StatefulWidget {
  const PharmacistEnterpriseShell({
    super.key,
    required this.userId,
    this.pharmacyName,
  });

  final String userId;
  final String? pharmacyName;

  @override
  State<PharmacistEnterpriseShell> createState() => _PharmacistEnterpriseShellState();
}

/// Back-compat alias used by login_screen.
typedef PharmacistInventoryDashboard = PharmacistEnterpriseShell;

class _PharmacistEnterpriseShellState extends State<PharmacistEnterpriseShell> {
  static const _pendingPollInterval = Duration(seconds: 15);
  static const _kBreakpoint = 900.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _sectionIndex = ValueNotifier<int>(0);
  late PharmacyInventoryApi _api = PharmacyInventoryApi(userId: widget.userId);
  Timer? _pendingRequestsPollTimer;

  bool _loading = true;
  String? _error;
  PharmacyWorkspace? _workspace;

  static const _navItems = <({IconData icon, String labelKey})>[
    (icon: Icons.dashboard_outlined, labelKey: 'pharmacistNavDashboardOverview'),
    (icon: Icons.medication_outlined, labelKey: 'pharmacistNavInventoryManagement'),
    (icon: Icons.history_edu_outlined, labelKey: 'pharmacistNavInventoryLogs'),
    (icon: Icons.point_of_sale_outlined, labelKey: 'pharmacistNavDispensingTerminal'),
    (icon: Icons.assignment_outlined, labelKey: 'pharmacistNavMedicationRequests'),
    (icon: Icons.notifications_active_outlined, labelKey: 'pharmacistNavSystemNotifications'),
    (icon: Icons.analytics_outlined, labelKey: 'pharmacistNavAnalyticReports'),
    (icon: Icons.settings_outlined, labelKey: 'pharmacistNavPharmacySettings'),
    (icon: Icons.badge_outlined, labelKey: 'pharmacistNavPharmacistProfile'),
  ];

  String _navLabel(BuildContext context, String labelKey) {
    final l10n = context.l10n;
    return switch (labelKey) {
      'pharmacistNavDashboardOverview' => l10n.pharmacistNavDashboardOverview,
      'pharmacistNavInventoryManagement' => l10n.pharmacistNavInventoryManagement,
      'pharmacistNavInventoryLogs' => l10n.pharmacistNavInventoryLogs,
      'pharmacistNavDispensingTerminal' => l10n.pharmacistNavDispensingTerminal,
      'pharmacistNavMedicationRequests' => l10n.pharmacistNavMedicationRequests,
      'pharmacistNavSystemNotifications' => l10n.pharmacistNavSystemNotifications,
      'pharmacistNavAnalyticReports' => l10n.pharmacistNavAnalyticReports,
      'pharmacistNavPharmacySettings' => l10n.pharmacistNavPharmacySettings,
      'pharmacistNavPharmacistProfile' => l10n.pharmacistNavPharmacistProfile,
      _ => labelKey,
    };
  }

  @override
  void dispose() {
    _pendingRequestsPollTimer?.cancel();
    _sectionIndex.dispose();
    super.dispose();
  }

  void _startPendingRequestsPolling() {
    _pendingRequestsPollTimer?.cancel();
    _pendingRequestsPollTimer = Timer.periodic(_pendingPollInterval, (_) {
      _workspace?.refreshPendingMedicationRequests();
    });
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final defaultPharmacyName = mounted ? context.l10n.pharmacistDefaultName : 'Rafeeq Pharmacy';
      var json = await _api.getDashboardByUser();
      if (json.isEmpty) {
        await _api.createPharmacy(
          name: widget.pharmacyName?.trim().isNotEmpty == true ? widget.pharmacyName!.trim() : defaultPharmacyName,
          latitude: 32.2211,
          longitude: 35.2544,
        );
        json = await _api.getDashboardByUser();
      }
      if (!mounted) return;
      final stats = PharmacyDashboardStats.fromJson(json);
      _api = PharmacyInventoryApi(userId: widget.userId, pharmacyId: stats.pharmacyId);
      _workspace = PharmacyWorkspace(
        api: _api,
        userId: widget.userId,
        pharmacyId: stats.pharmacyId,
        stats: stats,
        onRefresh: _refreshStats,
        sectionIndex: _sectionIndex,
      );
      await _workspace!.refreshPendingMedicationRequests();
      _startPendingRequestsPolling();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshStats() async {
    if (_workspace == null) return;
    final json = await _api.getDashboardByUser();
    if (json.isEmpty || !mounted) return;
    setState(() {
      _workspace!.stats = PharmacyDashboardStats.fromJson(json);
    });
  }

  @override
  void initState() {
    super.initState();
    PharmacistSession.instance.load();
    _bootstrap();
  }

  void _selectSection(int i) {
    _sectionIndex.value = i;
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
  }

  Widget _moduleHost() {
    return ValueListenableBuilder<int>(
      valueListenable: _sectionIndex,
      builder: (context, index, _) {
        return PharmacistModuleHost(
          index: index,
          workspace: _workspace!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: PharmacistTheme.bg,
        body: const Center(child: CircularProgressIndicator(color: PharmacistTheme.gold)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: PharmacistTheme.bg,
        body: _ErrorView(message: _error!, onRetry: _bootstrap),
      );
    }

    final wide = MediaQuery.sizeOf(context).width >= _kBreakpoint;
    final sidebar = _Sidebar(
      items: _navItems,
      navLabel: _navLabel,
      selectedIndex: _sectionIndex,
      pharmacyName: _workspace!.stats.pharmacyName,
      pendingMedicationRequests: _workspace!.pendingMedicationRequests,
      onSelect: _selectSection,
      onLogout: () => performPharmacistLogout(context),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PharmacistTheme.bg,
      drawer: wide ? null : Drawer(backgroundColor: PharmacistTheme.card, child: sidebar),
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: PharmacistTheme.card,
              foregroundColor: PharmacistTheme.gold,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: PharmacistTheme.gold),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: ValueListenableBuilder<int>(
                valueListenable: _sectionIndex,
                builder: (context, index, _) {
                  final labelKey = _navItems[index.clamp(0, _navItems.length - 1)].labelKey;
                  return Text(
                    _navLabel(context, labelKey),
                    style: PharmacistTheme.titleStyle(16),
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              actions: const [
                RafeeqLanguageToggle(iconColor: PharmacistTheme.gold),
              ],
            ),
      body: wide
          ? LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: constraints.maxHeight,
                  width: constraints.maxWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      sidebar,
                      Expanded(
                        child: Container(
                          color: PharmacistTheme.bg,
                          child: _moduleHost(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          : _moduleHost(),
      bottomNavigationBar: wide
          ? null
          : ValueListenableBuilder<int>(
              valueListenable: _sectionIndex,
              builder: (context, index, _) {
                return NavigationBar(
                  selectedIndex: index.clamp(0, 4),
                  onDestinationSelected: _selectSection,
                  backgroundColor: PharmacistTheme.card,
                  indicatorColor: PharmacistTheme.gold.withValues(alpha: 0.22),
                  destinations: [
                    for (final item in _navItems.take(5))
                      NavigationDestination(
                        icon: Icon(item.icon),
                        label: _navLabel(context, item.labelKey).split(' ').first,
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.navLabel,
    required this.selectedIndex,
    required this.pharmacyName,
    required this.pendingMedicationRequests,
    required this.onSelect,
    required this.onLogout,
  });

  final List<({IconData icon, String labelKey})> items;
  final String Function(BuildContext context, String labelKey) navLabel;
  final ValueNotifier<int> selectedIndex;
  final String pharmacyName;
  final ValueNotifier<int> pendingMedicationRequests;
  final void Function(int) onSelect;
  final VoidCallback onLogout;

  Widget _navIcon(int index, IconData icon, int pendingCount) {
    final iconWidget = Icon(icon, color: PharmacistTheme.gold, size: 22);
    if (index != kPharmacistMedicationRequestsNavIndex || pendingCount <= 0) {
      return iconWidget;
    }
    return Badge(
      isLabelVisible: true,
      label: Text(
        pendingCount > 99 ? '99+' : '$pendingCount',
        style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
      ),
      backgroundColor: const Color(0xFFE53935),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      offset: const Offset(6, -6),
      child: iconWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: PharmacistTheme.card,
      child: SizedBox(
        width: PharmacistTheme.sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.pharmacistBrandTitle,
                          style: PharmacistTheme.titleStyle(18).copyWith(color: PharmacistTheme.gold),
                        ),
                      ),
                      const RafeeqLanguageToggle(iconColor: PharmacistTheme.gold),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(pharmacyName, style: PharmacistTheme.bodyStyle(), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: selectedIndex,
                builder: (context, active, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: pendingMedicationRequests,
                    builder: (context, pendingCount, _) {
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final isActive = i == active;
                          return Material(
                            color: isActive ? PharmacistTheme.gold.withValues(alpha: 0.12) : Colors.transparent,
                            child: InkWell(
                              onTap: () => onSelect(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      child: _navIcon(i, item.icon, pendingCount),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        navLabel(context, item.labelKey),
                                        style: GoogleFonts.urbanist(
                                          color: isActive ? Colors.white : PharmacistTheme.greyText,
                                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (i == kPharmacistMedicationRequestsNavIndex && pendingCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE53935),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          pendingCount > 99 ? '99+' : '$pendingCount',
                                          style: GoogleFonts.urbanist(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
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
                },
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ListTile(
              dense: true,
              onTap: onLogout,
              leading: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
              title: Text(
                l10n.logOut,
                style: GoogleFonts.urbanist(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              hoverColor: Colors.redAccent.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: PharmacistTheme.gold, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: PharmacistTheme.bodyStyle()),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: PharmacistTheme.gold, foregroundColor: Colors.black),
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class PharmacistModuleHost extends StatelessWidget {
  const PharmacistModuleHost({super.key, required this.index, required this.workspace});

  final int index;
  final PharmacyWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final pages = [
      PharmacistOverviewPage(workspace: workspace),
      PharmacistInventoryPage(workspace: workspace),
      PharmacistInventoryLogsPage(workspace: workspace),
      PharmacistDispensingPage(workspace: workspace),
      PharmacistMedicationRequestsPage(workspace: workspace),
      PharmacistNotificationsPage(workspace: workspace),
      PharmacistAnalyticsPage(workspace: workspace),
      PharmacistSettingsPage(workspace: workspace),
      PharmacistProfilePage(workspace: workspace),
    ];

    return SizedBox.expand(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
        child: KeyedSubtree(
          key: ValueKey(index),
          child: pages[index.clamp(0, pages.length - 1)],
        ),
      ),
    );
  }
}
