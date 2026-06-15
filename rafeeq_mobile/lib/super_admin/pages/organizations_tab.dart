import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_extensions.dart';
import '../organization_detail_page.dart';
import '../super_admin_api.dart';
import '../super_admin_l10n_helpers.dart';
import '../super_admin_theme.dart';
import 'pharmacy_details_dashboard.dart';

class OrganizationsTab extends StatefulWidget {
  const OrganizationsTab({super.key});

  @override
  State<OrganizationsTab> createState() => _OrganizationsTabState();
}

class _OrganizationsTabState extends State<OrganizationsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orgs = [];
  String _filter = 'all';
  final _dateFmt = DateFormat('MMM d, yyyy');

  static const Color _pageBg = Color(0xFF121212);
  static const Color _cardBg = Color(0xFF1E1E1E);
  static const Color _gold = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statusQuery = _filter == 'all' ? null : _filter;
      final list = await SuperAdminApi.getOrganizations(status: statusQuery);
      if (!mounted) return;
      setState(() {
        _orgs = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return kSuperAdminSuccess;
      case 'pending':
        return Colors.orange.shade300;
      case 'suspended':
        return Colors.red.shade400;
      default:
        return Colors.white54;
    }
  }

  BoxDecoration _goldCardDecoration() => BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold, width: 1.2),
      );

  String? _resolvePharmacyId(Map<String, dynamic> org) {
    final pharmacies = org['pharmacies'];
    if (pharmacies is List && pharmacies.isNotEmpty) {
      final first = pharmacies.first;
      if (first is Map) {
        final id = (first['id'] ?? first['_id'])?.toString() ?? '';
        if (id.isNotEmpty) return id;
      }
    }
    final nested = org['pharmacy'];
    if (nested is Map) {
      final id = (nested['id'] ?? nested['_id'])?.toString() ?? '';
      if (id.isNotEmpty) return id;
    }
    return null;
  }

  void _openPharmacyDashboard(
    BuildContext context, {
    required Map<String, dynamic> org,
    required String pharmacyName,
    required String pharmacyEmail,
  }) {
    final pharmacyId = _resolvePharmacyId(org);
    if (pharmacyId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PharmacyDetailsDashboard(
          pharmacyId: pharmacyId,
          pharmacyName: pharmacyName.isNotEmpty ? pharmacyName : 'Pharmacy',
          pharmacyEmail: pharmacyEmail.isNotEmpty ? pharmacyEmail : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ColoredBox(
      color: _pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.superAdminRegisteredOrganizations, style: superAdminPremiumHeading(17)),
                ),
                _FilterDropdown(
                  value: _filter,
                  labels: {
                    'all': l10n.superAdminFilterAll,
                    'active': l10n.superAdminFilterActive,
                    'pending': l10n.superAdminFilterPending,
                    'suspended': l10n.superAdminFilterSuspended,
                  },
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _filter = v);
                      _load();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _gold))
                  : _error != null && _orgs.isEmpty
                      ? _ErrorBox(message: _error!, onRetry: _load)
                      : _orgs.isEmpty
                          ? Center(
                              child: Text(l10n.superAdminNoOrganizations, style: superAdminPremiumMuted(size: 14)),
                            )
                          : RefreshIndicator(
                              color: _gold,
                              backgroundColor: _cardBg,
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: _orgs.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final o = _orgs[i];
                                  final id = (o['id'] ?? o['_id'])?.toString() ?? '';
                                  final name = o['name']?.toString() ?? 'Unnamed';
                                  final status = o['status']?.toString() ?? 'active';
                                  final sub = o['subscriptionType']?.toString() ?? 'Free';
                                  final city = o['city']?.toString() ?? '';
                                  final registered =
                                      DateTime.tryParse(o['registeredAt']?.toString() ?? '');
                                  final pharmacyEmail = o['pharmacyEmail']?.toString() ?? '';
                                  final pharmacyName = o['pharmacyName']?.toString() ?? '';
                                  final pharmacies = o['pharmacies'];
                                  final hasPharmacy = pharmacyEmail.isNotEmpty ||
                                      pharmacyName.isNotEmpty ||
                                      (pharmacies is List && pharmacies.isNotEmpty);

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: id.isEmpty
                                          ? null
                                          : () => Navigator.push(
                                                context,
                                                MaterialPageRoute<void>(
                                                  builder: (_) => OrganizationDetailPage(
                                                    orgId: id,
                                                    orgName: name,
                                                  ),
                                                ),
                                              ),
                                      child: Container(
                                        decoration: _goldCardDecoration(),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: _gold.withValues(alpha: 0.15),
                                              child: const Icon(
                                                Icons.business_rounded,
                                                color: _gold,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    l10n.superAdminOrgStatusLine(
                                                      superAdminTranslateStatus(l10n, status),
                                                      superAdminTranslateSubscription(l10n, sub),
                                                    ),
                                                    style: TextStyle(
                                                      color: _statusColor(status),
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                  if (city.isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    Text(city, style: superAdminPremiumLabel(size: 12)),
                                                  ],
                                                  if (hasPharmacy) ...[
                                                    const SizedBox(height: 8),
                                                    InkWell(
                                                      borderRadius: BorderRadius.circular(8),
                                                      onTap: _resolvePharmacyId(o) == null
                                                          ? null
                                                          : () => _openPharmacyDashboard(
                                                                context,
                                                                org: o,
                                                                pharmacyName: pharmacyName,
                                                                pharmacyEmail: pharmacyEmail,
                                                              ),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: _gold.withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: _gold.withValues(alpha: 0.45),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.local_pharmacy_outlined,
                                                              color: _gold,
                                                              size: 16,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  if (pharmacyName.isNotEmpty)
                                                                    Text(
                                                                      pharmacyName,
                                                                      style: const TextStyle(
                                                                        color: Colors.white,
                                                                        fontSize: 12,
                                                                        fontWeight: FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  if (pharmacyEmail.isNotEmpty)
                                                                    Text(
                                                                      pharmacyEmail,
                                                                      style: TextStyle(
                                                                        color: _gold.withValues(alpha: 0.95),
                                                                        fontSize: 11.5,
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                            Icon(
                                                              Icons.open_in_new_rounded,
                                                              color: _gold.withValues(alpha: 0.85),
                                                              size: 14,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  if (registered != null) ...[
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      '${l10n.superAdminRegisteredOn} ${_dateFmt.format(registered)}',
                                                      style: superAdminPremiumMuted(size: 11.5),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right_rounded, color: _gold),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> labels;
  final ValueChanged<String?> onChanged;

  static const Color _cardBg = Color(0xFF1E1E1E);
  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: _cardBg,
          icon: const Icon(Icons.arrow_drop_down, color: _gold),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: [
            for (final entry in labels.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _pageBg = Color(0xFF121212);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _pageBg),
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
