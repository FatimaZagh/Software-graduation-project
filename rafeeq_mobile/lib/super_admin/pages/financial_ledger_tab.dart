import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extensions.dart';
import '../super_admin_api.dart';
import '../super_admin_l10n_helpers.dart';
import '../super_admin_theme.dart';

class FinancialLedgerTab extends StatefulWidget {
  const FinancialLedgerTab({super.key});

  @override
  State<FinancialLedgerTab> createState() => _FinancialLedgerTabState();
}

class _FinancialLedgerTabState extends State<FinancialLedgerTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _ledger = {};
  final _moneyFmt = NumberFormat('#,##0.00');
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
      final data = await SuperAdminApi.getFinancialLedger();
      if (!mounted) return;
      setState(() {
        _ledger = data;
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

  List<Map<String, dynamic>> _list(String key) {
    final raw = _ledger[key];
    if (raw is! List) return [];
    return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
  }

  BoxDecoration _goldCardDecoration() => BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold, width: 1.2),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = (_ledger['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final currency = summary['currency']?.toString() ?? 'ILS';
    final entities = _list('entities');
    final transactions = _list('recentTransactions');

    return Material(
      color: _pageBg,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _error != null && _ledger.isEmpty
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                )
              : RefreshIndicator(
                  color: _gold,
                  backgroundColor: _cardBg,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      Text(
                        l10n.superAdminLedgerTitle,
                        style: superAdminPremiumHeading(17),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _metricCard(l10n.superAdminOrganizationsMetric, '${summary['totalOrganizations'] ?? 0}'),
                          _metricCard(l10n.superAdminActiveMetric, '${summary['activeOrganizations'] ?? 0}'),
                          _metricCard(
                            l10n.superAdminPaymentsMetric,
                            '${_moneyFmt.format(summary['totalPaymentsCollected'] ?? 0)} $currency',
                          ),
                          _metricCard(
                            l10n.superAdminPendingInvoicesMetric,
                            '${_moneyFmt.format(summary['totalInvoicesPending'] ?? 0)} $currency',
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        l10n.superAdminEntitySubscriptions,
                        style: superAdminPremiumHeading(14),
                      ),
                      const SizedBox(height: 10),
                      if (entities.isEmpty)
                        Text(l10n.superAdminNoBillingEntities, style: superAdminPremiumMuted())
                      else
                        ...entities.map((e) => _entityCard(e, currency, l10n)),
                      const SizedBox(height: 22),
                      Text(
                        l10n.superAdminRecentTransactions,
                        style: superAdminPremiumHeading(14),
                      ),
                      const SizedBox(height: 10),
                      if (transactions.isEmpty)
                        Text(l10n.superAdminNoTransactions, style: superAdminPremiumMuted())
                      else
                        ...transactions.take(30).map((t) => _transactionCard(t, currency)),
                    ],
                  ),
                ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: _goldCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: superAdminPremiumLabel(size: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: superAdminPremiumValue(size: 16).copyWith(color: _gold),
          ),
        ],
      ),
    );
  }

  Widget _entityCard(Map<String, dynamic> e, String currency, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _goldCardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e['orgName']?.toString() ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${superAdminTranslateSubscription(l10n, e['subscriptionType']?.toString() ?? 'Free')} · ${superAdminTranslateStatus(l10n, e['status']?.toString() ?? '')}',
                  style: superAdminPremiumLabel(size: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_moneyFmt.format(e['paymentsCollected'] ?? 0)} $currency',
                style: superAdminPremiumValue(size: 14).copyWith(color: _gold),
              ),
              Text(
                l10n.superAdminPendingAmount('${_moneyFmt.format(e['invoicesPending'] ?? 0)} $currency'),
                style: superAdminPremiumMuted(size: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transactionCard(Map<String, dynamic> t, String currency) {
    final date = DateTime.tryParse(t['date']?.toString() ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _goldCardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            t['type'] == 'payment' ? Icons.payments_outlined : Icons.receipt_long_outlined,
            color: _gold,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t['orgName']?.toString() ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${t['type'] ?? ''} · ${t['status'] ?? ''}${date != null ? ' · ${_dateFmt.format(date)}' : ''}',
                  style: superAdminPremiumLabel(size: 11.5),
                ),
              ],
            ),
          ),
          Text(
            '${_moneyFmt.format(t['amount'] ?? 0)} $currency',
            style: superAdminPremiumValue(size: 13.5).copyWith(color: _gold),
          ),
        ],
      ),
    );
  }
}
