import 'package:flutter/material.dart';

import '../l10n/l10n_extensions.dart';
import '../widgets/rafeeq_back_home_button.dart';
import '../widgets/rafeeq_language_toggle.dart';
import 'pages/medical_orders_feed_tab.dart';
import 'pages/organizations_tab.dart';
import 'pages/pending_applications_tab.dart';
import 'platform_super_admin_session.dart';
import 'super_admin_theme.dart';

/// Centralized platform management shell with multi-level navigation.
class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _index = 0;
  int _refreshKey = 0;

  void _logout() {
    PlatformSuperAdminSession.clear();
    rafeeqNavigateBackToHome(context);
  }

  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final tabs = <_NavItem>[
      _NavItem(
        icon: Icons.monitor_heart_outlined,
        label: l10n.superAdminMedicalOrdersFeed,
        builder: (_) => MedicalOrdersFeedTab(key: ValueKey('orders_$_refreshKey')),
      ),
      _NavItem(
        icon: Icons.apartment_rounded,
        label: l10n.superAdminRegisteredOrganizations,
        builder: (_) => OrganizationsTab(key: ValueKey('orgs_$_refreshKey')),
      ),
      _NavItem(
        icon: Icons.pending_actions_rounded,
        label: l10n.superAdminPendingApplications,
        builder: (_) => PendingApplicationsTab(key: ValueKey('pending_$_refreshKey')),
      ),
    ];

    final body = tabs[_index].builder(context);

    return Scaffold(
      backgroundColor: kSuperAdminPremiumBg,
      appBar: AppBar(
        backgroundColor: kSuperAdminBlueDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.superAdminPlatformTitle, style: superAdminTitle(17)),
            Text(
              l10n.superAdminPlatformSubtitle,
              style: superAdminTitle(11).copyWith(fontWeight: FontWeight.w500, color: kSuperAdminGold.withValues(alpha: 0.9)),
            ),
          ],
        ),
        actions: [
          const RafeeqLanguageToggle(iconColor: kSuperAdminGold),
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          TextButton(
            onPressed: _logout,
            child: Text(l10n.logOut, style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  backgroundColor: kSuperAdminBlueDark,
                  indicatorColor: kSuperAdminGold.withValues(alpha: 0.22),
                  selectedIconTheme: const IconThemeData(color: kSuperAdminGold),
                  unselectedIconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.72)),
                  selectedLabelTextStyle: superAdminPremiumValue(size: 12).copyWith(color: kSuperAdminGold),
                  unselectedLabelTextStyle: superAdminPremiumLabel(size: 11),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final t in tabs)
                      NavigationRailDestination(icon: Icon(t.icon), label: Text(t.label)),
                  ],
                ),
                Container(width: 1, color: kSuperAdminGold.withValues(alpha: 0.25)),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              backgroundColor: kSuperAdminBlueDark,
              indicatorColor: kSuperAdminGold.withValues(alpha: 0.22),
              surfaceTintColor: Colors.transparent,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return superAdminPremiumLabel(size: 11).copyWith(
                  color: selected ? kSuperAdminGold : Colors.white70,
                );
              }),
              destinations: [
                for (final t in tabs)
                  NavigationDestination(
                    icon: Icon(t.icon, color: Colors.white70),
                    selectedIcon: Icon(t.icon, color: kSuperAdminGold),
                    label: t.label,
                  ),
              ],
            ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.builder});

  final IconData icon;
  final String label;
  final WidgetBuilder builder;
}
