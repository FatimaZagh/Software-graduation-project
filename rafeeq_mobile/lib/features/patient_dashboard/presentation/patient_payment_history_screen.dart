import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../data/patient_portal_api.dart';
import 'patient_theme.dart';

const Color _kReportBg = Color(0xFF121212);
const Color _kReportCard = Color(0xFF1E1E1E);
const Color _kReportMuted = Color(0xFFB3B3B3);

class PatientPaymentHistoryScreen extends StatefulWidget {
  const PatientPaymentHistoryScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<PatientPaymentHistoryScreen> createState() => _PatientPaymentHistoryScreenState();
}

class _PatientPaymentHistoryScreenState extends State<PatientPaymentHistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  double _totalPaid = 0;
  String _currency = 'ILS';
  bool _loading = true;
  String? _error;
  final _dateFmt = DateFormat('MMM d, yyyy · HH:mm');

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
      final payload = await PatientPortalApi.getPaymentHistory(widget.patientUserId);
      if (!mounted) return;
      final summaryRaw = payload['summary'];
      final summary = summaryRaw is Map ? Map<String, dynamic>.from(summaryRaw) : <String, dynamic>{};
      final list = payload['transactions'] as List<dynamic>? ?? [];
      setState(() {
        _transactions = [
          for (final item in list)
            if (item is Map) Map<String, dynamic>.from(item),
        ];
        _totalPaid = (summary['totalPaid'] as num?)?.toDouble() ?? 0;
        _currency = summary['currency']?.toString() ?? 'ILS';
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

  String _statusLabel(String status, bool isArabic) {
    switch (status) {
      case 'Paid':
        return isArabic ? 'مدفوع' : 'Paid';
      case 'Failed':
        return isArabic ? 'فشل' : 'Failed';
      default:
        return isArabic ? 'قيد الانتظار' : 'Pending';
    }
  }

  String _serviceLabel(String serviceType, bool isArabic) {
    switch (serviceType) {
      case 'Consultation':
        return isArabic ? 'استشارة' : 'Consultation';
      case 'Pharmacy':
        return isArabic ? 'صيدلية' : 'Pharmacy';
      default:
        return isArabic ? 'خدمة صحية' : 'Healthcare';
    }
  }

  String _transactionHeadline(Map<String, dynamic> tx, bool isArabic) {
    final status = tx['paymentStatus']?.toString() ?? 'Pending';
    final amount = (tx['amountPaid'] as num?)?.toDouble() ?? 0;
    final currency = tx['currency']?.toString() ?? _currency;
    final serviceType = tx['serviceType']?.toString() ?? 'Other';
    final serviceLabel = _serviceLabel(serviceType, isArabic);
    final detail = serviceType == 'Pharmacy'
        ? (tx['medicationName']?.toString() ?? (isArabic ? 'دواء' : 'Medication'))
        : serviceType == 'Consultation'
            ? (isArabic ? 'رسوم الاستشارة' : 'Consultation fee')
            : (tx['medicationName']?.toString() ?? serviceLabel);
    final reason = tx['failureReason']?.toString().trim() ?? '';

    if (status == 'Paid') {
      return isArabic
          ? 'تم الدفع — $amount $currency · $serviceLabel · $detail'
          : 'Payment successful — $amount $currency · $serviceLabel · $detail';
    }
    if (status == 'Failed') {
      final failDetail = reason.isNotEmpty
          ? reason
          : (isArabic ? 'تعذر إتمام الدفع' : 'Payment could not be processed');
      return isArabic ? 'فشل الدفع — $failDetail' : 'Payment failed — $failDetail';
    }
    return isArabic
        ? 'دفع قيد الانتظار — $amount $currency · $serviceLabel'
        : 'Payment pending — $amount $currency · $serviceLabel';
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final amountLabel = isArabic ? 'المبلغ' : 'Amount';
    final statusLabel = isArabic ? 'الحالة' : 'Status';
    final serviceLabel = isArabic ? 'نوع الخدمة' : 'Service';
    final txnIdLabel = isArabic ? 'رقم المعاملة' : 'Transaction ID';
    final totalLabel = isArabic ? 'إجمالي المصاريف الصحية' : 'Total Healthcare Expenditures';
    final emptyLabel = isArabic ? 'لا توجد معاملات مسجلة بعد' : 'No transactions recorded yet';
    final retryLabel = isArabic ? 'إعادة المحاولة' : 'Retry';

    return Scaffold(
      backgroundColor: _kReportBg,
      appBar: AppBar(
        backgroundColor: _kReportBg,
        foregroundColor: kPatientGold,
        elevation: 0,
        title: Text(l10n.paymentHistory, style: patientTitleStyle(18)),
        actions: [
          IconButton(
            tooltip: isArabic ? 'تحديث' : 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kPatientGold),
            )
          : _error != null
              ? _ErrorState(message: _error!, retryLabel: retryLabel, onRetry: _load)
              : RefreshIndicator(
                  color: kPatientGold,
                  backgroundColor: _kReportCard,
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: _SummaryCard(
                            totalLabel: totalLabel,
                            totalPaid: _totalPaid,
                            currency: _currency,
                            transactionCount: _transactions.length,
                            isArabic: isArabic,
                          ),
                        ),
                      ),
                      if (_transactions.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(label: emptyLabel, isArabic: isArabic),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList.separated(
                            itemCount: _transactions.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final tx = _transactions[index];
                              final status = tx['paymentStatus']?.toString() ?? 'Pending';
                              final serviceType = tx['serviceType']?.toString() ?? 'Other';
                              final transactionId = tx['transactionId']?.toString() ?? tx['id']?.toString() ?? '—';
                              final date = _parseDate(tx['transactionDate']);
                              final pharmacy = tx['pharmacyName']?.toString().trim() ?? '';
                              final amount = (tx['amountPaid'] as num?)?.toDouble() ?? 0;
                              final currency = tx['currency']?.toString() ?? _currency;
                              final medication = tx['medicationName']?.toString() ?? '—';
                              final isPharmacy = serviceType == 'Pharmacy';

                              return _TransactionTile(
                                headline: _transactionHeadline(tx, isArabic),
                                serviceLabel: serviceLabel,
                                serviceText: _serviceLabel(serviceType, isArabic),
                                txnIdLabel: txnIdLabel,
                                transactionId: transactionId,
                                detailLabel: isPharmacy
                                    ? (isArabic ? 'الدواء' : 'Medication')
                                    : (isArabic ? 'التفاصيل' : 'Details'),
                                detailValue: medication,
                                amountLabel: amountLabel,
                                amountText: '$amount $currency',
                                statusLabel: statusLabel,
                                statusText: _statusLabel(status, isArabic),
                                pharmacyName: pharmacy,
                                showPharmacy: isPharmacy && pharmacy.isNotEmpty,
                                timestamp: date != null ? _dateFmt.format(date.toLocal()) : '—',
                                status: status,
                                isArabic: isArabic,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalLabel,
    required this.totalPaid,
    required this.currency,
    required this.transactionCount,
    required this.isArabic,
  });

  final String totalLabel;
  final double totalPaid;
  final String currency;
  final int transactionCount;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final countLabel = isArabic
        ? '$transactionCount معاملة'
        : '$transactionCount transaction${transactionCount == 1 ? '' : 's'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kReportCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPatientGold, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: kPatientGold.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: kPatientGold.withValues(alpha: 0.9)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  totalLabel,
                  style: GoogleFonts.urbanist(
                    color: kPatientGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${totalPaid.toStringAsFixed(totalPaid.truncateToDouble() == totalPaid ? 0 : 2)} $currency',
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            countLabel,
            style: GoogleFonts.urbanist(color: _kReportMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.headline,
    required this.serviceLabel,
    required this.serviceText,
    required this.txnIdLabel,
    required this.transactionId,
    required this.detailLabel,
    required this.detailValue,
    required this.amountLabel,
    required this.amountText,
    required this.statusLabel,
    required this.statusText,
    required this.pharmacyName,
    required this.showPharmacy,
    required this.timestamp,
    required this.status,
    required this.isArabic,
  });

  final String headline;
  final String serviceLabel;
  final String serviceText;
  final String txnIdLabel;
  final String transactionId;
  final String detailLabel;
  final String detailValue;
  final String amountLabel;
  final String amountText;
  final String statusLabel;
  final String statusText;
  final String pharmacyName;
  final bool showPharmacy;
  final String timestamp;
  final String status;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final isPaid = status == 'Paid';
    final isFailed = status == 'Failed';
    final accent = isPaid
        ? const Color(0xFF4CAF50)
        : isFailed
            ? Colors.orangeAccent
            : kPatientGold;

    return Container(
      decoration: BoxDecoration(
        color: _kReportCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPatientGold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaid
                        ? Icons.check_circle_rounded
                        : isFailed
                            ? Icons.warning_amber_rounded
                            : Icons.schedule_rounded,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    headline,
                    style: GoogleFonts.urbanist(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailRow(label: txnIdLabel, value: transactionId),
            const SizedBox(height: 8),
            _DetailRow(label: serviceLabel, value: serviceText),
            const SizedBox(height: 8),
            _DetailRow(label: detailLabel, value: detailValue),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _DetailRow(label: amountLabel, value: amountText)),
                const SizedBox(width: 12),
                Expanded(child: _DetailRow(label: statusLabel, value: statusText, valueColor: accent)),
              ],
            ),
            if (showPharmacy) ...[
              const SizedBox(height: 8),
              _DetailRow(
                label: isArabic ? 'الصيدلية' : 'Pharmacy',
                value: pharmacyName,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: _kReportMuted),
                const SizedBox(width: 6),
                Text(
                  timestamp,
                  style: GoogleFonts.urbanist(color: _kReportMuted, fontSize: 12.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.urbanist(color: _kReportMuted, fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.urbanist(
            color: valueColor ?? Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label, required this.isArabic});

  final String label;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _kReportCard,
                shape: BoxShape.circle,
                border: Border.all(color: kPatientGold.withValues(alpha: 0.45)),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 44,
                color: kPatientGold.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'ستظهر مدفوعات الصيدلية والعيادة هنا بعد إتمامها.'
                  : 'Pharmacy and clinic payments will appear here once completed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(color: _kReportMuted, fontSize: 13.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent.shade200, size: 42),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: kPatientGold,
                foregroundColor: _kReportBg,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
