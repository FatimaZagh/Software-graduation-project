import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extensions.dart';
import '../super_admin_api.dart';
import '../super_admin_theme.dart';

class MedicalOrdersFeedTab extends StatefulWidget {
  const MedicalOrdersFeedTab({super.key});

  @override
  State<MedicalOrdersFeedTab> createState() => _MedicalOrdersFeedTabState();
}

class _MedicalOrdersFeedTabState extends State<MedicalOrdersFeedTab> {
  static const Color _pageBg = kSuperAdminPremiumBg;
  static const Color _cardBg = kSuperAdminPremiumCard;
  static const Color _gold = kSuperAdminGold;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _allOrders = [];
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _platformStats = {};
  Timer? _poll;

  final _dateFmt = DateFormat('MMM d, yyyy · HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await SuperAdminApi.getMedicalOrdersFeed();
      if (!mounted) return;
      setState(() {
        _allOrders = _list(data['allOrders']);
        _summary = (data['summary'] as Map?)?.cast<String, dynamic>() ?? {};
        _platformStats = (data['platformStats'] as Map?)?.cast<String, dynamic>() ?? {};
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent || _allOrders.isEmpty) _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is! List) return [];
    return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
  }

  BoxDecoration _goldCardDecoration() => BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold, width: 1.2),
      );

  Color _typeTint(String orderType) {
    switch (orderType) {
      case 'LAB_TEST':
        return const Color(0xFF4FC3F7);
      case 'IMAGING':
        return const Color(0xFFBA68C8);
      case 'PRESCRIPTION':
        return const Color(0xFF81C784);
      default:
        return _gold;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return kSuperAdminSuccess;
      case 'Pending':
        return _gold;
      case 'Requested':
      default:
        return Colors.white54;
    }
  }

  String _typeLabel(Map<String, dynamic> order, AppLocalizations l10n) {
    final label = order['requestTypeLabel']?.toString() ?? '';
    switch (label) {
      case 'LAB TEST':
        return l10n.superAdminOrderTypeLab;
      case 'IMAGING':
        return l10n.superAdminOrderTypeImaging;
      case 'PRESCRIPTION':
        return l10n.superAdminOrderTypePrescription;
      default:
        return label;
    }
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'Completed':
        return l10n.superAdminOrderStatusCompleted;
      case 'Pending':
        return l10n.superAdminOrderStatusPending;
      case 'Requested':
      default:
        return l10n.superAdminOrderStatusRequested;
    }
  }

  int _gridColumns(double width, {int maxCols = 4}) {
    if (width >= 1100) return maxCols;
    if (width >= 720) return math.min(3, maxCols);
    if (width >= 480) return 2;
    return 2;
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    Color? accent,
  }) {
    final tint = accent ?? _gold;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _goldCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: superAdminPremiumValue(size: 20).copyWith(color: tint),
          ),
          const SizedBox(height: 4),
          Text(label, style: superAdminPremiumLabel(size: 11.5)),
        ],
      ),
    );
  }

  Widget _responsiveGrid({
    required double width,
    required int maxCols,
    required double spacing,
    required List<Widget> children,
  }) {
    final cols = _gridColumns(width, maxCols: maxCols);
    final itemWidth = (width - spacing * (cols - 1)) / cols;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final child in children)
          SizedBox(
            width: itemWidth,
            child: child,
          ),
      ],
    );
  }

  Widget _orderCard(Map<String, dynamic> order, AppLocalizations l10n) {
    final orderType = order['orderType']?.toString() ?? '';
    final typeTint = _typeTint(orderType);
    final status = order['status']?.toString() ?? 'Requested';
    final createdRaw = order['createdAt']?.toString();
    final created = createdRaw != null ? DateTime.tryParse(createdRaw) : null;
    final patientId = order['patientUserId']?.toString() ?? '—';
    final shortPatient = patientId.length > 10 ? '…${patientId.substring(patientId.length - 8)}' : patientId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _goldCardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: typeTint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: typeTint.withValues(alpha: 0.55)),
                ),
                child: Text(
                  _typeLabel(order, l10n),
                  style: superAdminPremiumValue(size: 11).copyWith(
                    color: typeTint,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _statusColor(status).withValues(alpha: 0.65)),
                ),
                child: Text(
                  _statusLabel(status, l10n),
                  style: superAdminPremiumLabel(size: 11).copyWith(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order['title']?.toString() ?? '—',
            style: superAdminPremiumValue(size: 15),
          ),
          if ((order['detail']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(order['detail']!.toString(), style: superAdminPremiumMuted(size: 12)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _infoChip(Icons.person_outline, order['initiatorName']?.toString() ?? '—'),
              _infoChip(Icons.badge_outlined, '${l10n.superAdminPatientIdLabel}: $shortPatient'),
              _infoChip(Icons.local_hospital_outlined, order['clinicName']?.toString() ?? '—'),
              _infoChip(Icons.apartment_outlined, order['facilityName']?.toString() ?? '—'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            created != null ? _dateFmt.format(created.toLocal()) : '—',
            style: superAdminPremiumMuted(size: 11),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white54),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text, style: superAdminPremiumLabel(size: 11), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ColoredBox(
      color: _pageBg,
      child: _loading && _allOrders.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _error != null && _allOrders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: _gold,
                  backgroundColor: _cardBg,
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final contentWidth = constraints.maxWidth - 32;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(l10n.superAdminMedicalOrdersFeedTitle, style: superAdminPremiumHeading(17)),
                              ),
                              if (_loading)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(l10n.superAdminMedicalOrdersFeedSubtitle, style: superAdminPremiumMuted(size: 12.5)),
                          const SizedBox(height: 18),
                          Text(l10n.superAdminPlatformOverview, style: superAdminPremiumHeading(14)),
                          const SizedBox(height: 10),
                          _responsiveGrid(
                            width: contentWidth,
                            maxCols: 4,
                            spacing: 12,
                            children: [
                              _statCard(
                                label: l10n.superAdminStatClinics,
                                value: '${_platformStats['clinics'] ?? 0}',
                                icon: Icons.local_hospital_outlined,
                              ),
                              _statCard(
                                label: l10n.superAdminStatSystemUsers,
                                value: '${_platformStats['systemUsers'] ?? 0}',
                                icon: Icons.groups_outlined,
                              ),
                              _statCard(
                                label: l10n.superAdminStatDoctors,
                                value: '${_platformStats['doctors'] ?? 0}',
                                icon: Icons.medical_services_outlined,
                              ),
                              _statCard(
                                label: l10n.superAdminStatTotalPatients,
                                value: '${_platformStats['totalPatients'] ?? 0}',
                                icon: Icons.people_outline,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Text(l10n.superAdminLiveOrderActivity, style: superAdminPremiumHeading(14)),
                          const SizedBox(height: 10),
                          _responsiveGrid(
                            width: contentWidth,
                            maxCols: 4,
                            spacing: 12,
                            children: [
                              _statCard(
                                label: l10n.superAdminOrdersTotal,
                                value: '${_summary['total'] ?? _allOrders.length}',
                                icon: Icons.monitor_heart_outlined,
                              ),
                              _statCard(
                                label: l10n.superAdminOrdersLab,
                                value: '${_summary['labTests'] ?? 0}',
                                icon: Icons.biotech_outlined,
                                accent: _typeTint('LAB_TEST'),
                              ),
                              _statCard(
                                label: l10n.superAdminOrdersImaging,
                                value: '${_summary['imaging'] ?? 0}',
                                icon: Icons.radar_outlined,
                                accent: _typeTint('IMAGING'),
                              ),
                              _statCard(
                                label: l10n.superAdminOrdersRx,
                                value: '${_summary['prescriptions'] ?? 0}',
                                icon: Icons.medication_outlined,
                                accent: _typeTint('PRESCRIPTION'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          if (_allOrders.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(child: Text(l10n.superAdminNoMedicalOrders, style: superAdminPremiumMuted())),
                            )
                          else
                            ..._allOrders.map((o) => _orderCard(o, l10n)),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}
