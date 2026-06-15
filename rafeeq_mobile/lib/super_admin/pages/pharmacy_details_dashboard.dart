import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_extensions.dart';
import '../super_admin_api.dart';
import '../super_admin_l10n_helpers.dart';
import '../super_admin_theme.dart';

class PharmacyDetailsDashboard extends StatefulWidget {
  const PharmacyDetailsDashboard({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
    this.pharmacyEmail,
  });

  final String pharmacyId;
  final String pharmacyName;
  final String? pharmacyEmail;

  @override
  State<PharmacyDetailsDashboard> createState() => _PharmacyDetailsDashboardState();
}

class _PharmacyDetailsDashboardState extends State<PharmacyDetailsDashboard> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  final _moneyFmt = NumberFormat('#,##0.00');

  static const Color _pageBg = kSuperAdminPremiumBg;
  static const Color _cardBg = kSuperAdminPremiumCard;
  static const Color _gold = kSuperAdminGold;

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
      final data = await SuperAdminApi.getPharmacyDetails(widget.pharmacyId);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  Map<String, dynamic> _section(String key) {
    final raw = _data[key];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  List<Map<String, dynamic>> _shortages() {
    final inv = _section('inventory');
    final raw = inv['shortages'];
    if (raw is! List) return [];
    return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
  }

  BoxDecoration _goldCardDecoration() => superAdminPremiumCardDecoration();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sales = _section('sales');
    final inventory = _section('inventory');
    final prescriptions = _section('prescriptions');
    final pharmacy = _section('pharmacy');
    final currency = sales['currency']?.toString() ?? 'ILS';
    final shortages = _shortages();
    final displayName = pharmacy['name']?.toString().isNotEmpty == true
        ? pharmacy['name'].toString()
        : widget.pharmacyName;
    final displayEmail = pharmacy['email']?.toString().isNotEmpty == true
        ? pharmacy['email'].toString()
        : (widget.pharmacyEmail ?? '');

    return Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: _pageBg,
          elevation: 0,
          iconTheme: const IconThemeData(color: _gold),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: superAdminTitle(17),
              ),
              if (displayEmail.isNotEmpty)
                Text(
                  displayEmail,
                  style: superAdminPremiumMuted(size: 12),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: l10n.refresh,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, color: _gold),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : _error != null && _data.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: _gold),
                            onPressed: _load,
                            child: Text(l10n.retry, style: const TextStyle(color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: _gold,
                    backgroundColor: _cardBg,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        Text(
                          l10n.superAdminPharmacyDashboardTitle,
                          style: superAdminPremiumHeading(17),
                        ),
                        const SizedBox(height: 16),

                        // Section A — Sales & Financials
                        _SectionHeader(title: l10n.superAdminSalesAndFinancials),
                        const SizedBox(height: 10),
                        Container(
                          decoration: _goldCardDecoration(),
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _MetricTile(
                                label: l10n.superAdminTotalSales,
                                value: '${_moneyFmt.format(_num(sales['totalSales']))} $currency',
                                icon: Icons.payments_outlined,
                              ),
                              _MetricTile(
                                label: l10n.superAdminMonthlyRevenue,
                                value: '${_moneyFmt.format(_num(sales['monthlyRevenue']))} $currency',
                                icon: Icons.calendar_month_outlined,
                              ),
                              _MetricTile(
                                label: l10n.superAdminWalletBalance,
                                value: '${_moneyFmt.format(_num(pharmacy['walletBalance']))} $currency',
                                icon: Icons.account_balance_wallet_outlined,
                              ),
                              _MetricTile(
                                label: l10n.superAdminTotalOrders,
                                value: '${_int(sales['totalTransactions'])}',
                                icon: Icons.receipt_long_outlined,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Section B — Inventory shortages
                        _SectionHeader(title: l10n.superAdminInventoryShortages),
                        const SizedBox(height: 6),
                        Text(
                          '${inventory['lowStockItems'] ?? 0} ${superAdminTranslateInventoryStatus(l10n, 'Low Stock')} · '
                          '${inventory['outOfStockItems'] ?? 0} ${superAdminTranslateInventoryStatus(l10n, 'Out of Stock')}',
                          style: superAdminPremiumMuted(size: 12.5),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: _goldCardDecoration(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: shortages.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    l10n.superAdminNoShortages,
                                    style: superAdminPremiumValue(size: 14),
                                  ),
                                )
                              : Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              l10n.superAdminMedicineName,
                                              style: superAdminPremiumHeading(13),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              l10n.superAdminStockStatus,
                                              style: superAdminPremiumHeading(13),
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(color: Colors.white12, height: 1),
                                    ...shortages.map((row) => _ShortageRow(
                                          name: row['name']?.toString() ?? '—',
                                          status: superAdminTranslateInventoryStatus(
                                            l10n,
                                            row['status']?.toString() ?? '',
                                          ),
                                          isCritical: _isOutOfStock(row['status']?.toString() ?? ''),
                                        )),
                                  ],
                                ),
                        ),

                        const SizedBox(height: 24),

                        // Section C — Active prescriptions
                        _SectionHeader(title: l10n.superAdminActivePrescriptions),
                        const SizedBox(height: 10),
                        Container(
                          decoration: _goldCardDecoration(),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _PrescriptionCounter(
                                  label: l10n.superAdminPendingOrders,
                                  count: _int(prescriptions['pending']),
                                  color: const Color(0xFFFFB74D),
                                  icon: Icons.hourglass_top_rounded,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 72,
                                color: _gold.withValues(alpha: 0.35),
                              ),
                              Expanded(
                                child: _PrescriptionCounter(
                                  label: l10n.superAdminProcessedOrders,
                                  count: _int(prescriptions['processed']),
                                  color: const Color(0xFF81C784),
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 72,
                                color: _gold.withValues(alpha: 0.35),
                              ),
                              Expanded(
                                child: _PrescriptionCounter(
                                  label: l10n.superAdminTotalOrders,
                                  count: _int(prescriptions['total']),
                                  color: Colors.white,
                                  icon: Icons.medication_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
    );
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  bool _isOutOfStock(String status) {
    return status.toLowerCase().replaceAll(' ', '_').contains('out');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: kSuperAdminGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: superAdminPremiumHeading(15)),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSuperAdminPremiumBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kSuperAdminGold.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: kSuperAdminGold, size: 20),
            const SizedBox(height: 8),
            Text(label, style: superAdminPremiumLabel(size: 11.5)),
            const SizedBox(height: 4),
            Text(value, style: superAdminPremiumValue(size: 15)),
          ],
        ),
      ),
    );
  }
}

class _ShortageRow extends StatelessWidget {
  const _ShortageRow({
    required this.name,
    required this.status,
    required this.isCritical,
  });

  final String name;
  final String status;
  final bool isCritical;

  @override
  Widget build(BuildContext context) {
    final statusColor = isCritical ? const Color(0xFFEF5350) : const Color(0xFFFFB74D);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(name, style: superAdminPremiumValue(size: 13.5)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.6)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrescriptionCounter extends StatelessWidget {
  const _PrescriptionCounter({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: superAdminPremiumLabel(size: 11),
        ),
      ],
    );
  }
}
