import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../tenant_state.dart';
import '../../auth/data/pharmacy_cities.dart';
import '../data/patient_portal_api.dart';
import 'patient_nearby_pharmacies_sheet.dart';
import 'patient_theme.dart';

/// Medication requests + purchased meds with pull-to-refresh and live polling.
class PatientPurchasedMedicationsScreen extends StatefulWidget {
  const PatientPurchasedMedicationsScreen({
    super.key,
    required this.patientUserId,
    this.initialTabIndex = 0,
  });

  final String patientUserId;
  final int initialTabIndex;

  @override
  State<PatientPurchasedMedicationsScreen> createState() => _PatientPurchasedMedicationsScreenState();
}

class _PatientPurchasedMedicationsScreenState extends State<PatientPurchasedMedicationsScreen>
    with SingleTickerProviderStateMixin {
  static const _pollInterval = Duration(seconds: 15);

  late final TabController _tabController;
  Timer? _pollTimer;

  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _purchases = [];
  bool _loading = true;
  String? _error;
  final _dateFmt = DateFormat('MMM d, yyyy · HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _loadAll();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted) _loadAll(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        PatientPortalApi.getMedicationRequests(widget.patientUserId),
        PatientPortalApi.getPatientPurchases(widget.patientUserId),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0];
        _purchases = results[1];
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = e.toString();
        _loading = false;
      });
    }
  }

  String _displayStatus(BuildContext context, String raw) {
    final l10n = context.l10n;
    switch (raw) {
      case 'Approved':
      case 'Paid':
        return l10n.patientPaidConfirmed;
      case 'Partially Fulfilled':
        return l10n.patientPartiallyFulfilled;
      case 'Failed':
        return l10n.patientPaymentFailed;
      default:
        return raw.isEmpty ? l10n.patientPending : raw;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
      case 'Paid':
      case 'Dispensed':
        return const Color(0xFF4CAF50);
      case 'Partially Fulfilled':
        return kPatientGold;
      case 'Failed':
      case 'Rejected':
        return Colors.redAccent;
      default:
        return kPatientGold;
    }
  }

  int _backorderQty(Map<String, dynamic> r) {
    final direct = (r['backorderQuantity'] as num?)?.toInt();
    if (direct != null && direct > 0) return direct;
    final lines = r['lineItems'] as List<dynamic>? ?? [];
    for (final line in lines) {
      if (line is! Map) continue;
      final type = line['lineType']?.toString();
      final status = line['status']?.toString();
      if (type == 'Backorder' || status == 'Backorder' || status == 'Awaiting Stock') {
        return (line['quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  int _fulfilledQty(Map<String, dynamic> r) {
    final direct = (r['fulfilledQuantity'] as num?)?.toInt();
    if (direct != null && direct > 0) return direct;
    final lines = r['lineItems'] as List<dynamic>? ?? [];
    for (final line in lines) {
      if (line is! Map) continue;
      if (line['lineType']?.toString() == 'Fulfilled') {
        return (line['quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  bool _hasBackorder(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? '';
    return status == 'Partially Fulfilled' || _backorderQty(r) > 0;
  }

  Future<void> _openNearbyForBackorder(Map<String, dynamic> r) async {
    final drugId = r['drugId']?.toString() ?? '';
    final drugName = r['medicationName']?.toString() ?? 'Medication';
    final pharmacyId = r['pharmacyId']?.toString();
    final remaining = _backorderQty(r);
    if (drugId.isEmpty || remaining <= 0) return;

    LatLng origin = kPharmacyCities.first.center;
    try {
      final clinicId = TenantState.instance.preferredClinicId.trim();
      final routing = await PatientPortalApi.getPharmacyRouting(
        widget.patientUserId,
        drugId: drugId,
        clinicId: clinicId.isEmpty ? null : clinicId,
        lat: origin.latitude,
        lng: origin.longitude,
      );
      final internal = routing['internalPharmacy'];
      if (internal is Map) {
        final lat = internal['latitude'];
        final lng = internal['longitude'];
        if (lat != null && lng != null) {
          origin = LatLng((lat as num).toDouble(), (lng as num).toDouble());
        }
      }
    } catch (_) {}

    if (!mounted) return;
    await showPatientNearbyPharmaciesSheet(
      context,
      drugId: drugId,
      drugName: drugName,
      searchOrigin: origin,
      excludePharmacyId: pharmacyId,
      remainingQty: remaining,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: kPatientWorkspaceBlack,
      appBar: AppBar(
        backgroundColor: kPatientWorkspaceBlack,
        foregroundColor: kPatientGold,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.patientPharmacyActivity, style: patientTitleStyle(17)),
            Text(
              l10n.patientPharmacyActivitySubtitle,
              style: GoogleFonts.urbanist(color: kPatientGold.withValues(alpha: 0.85), fontSize: 12),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kPatientGold,
          labelColor: kPatientGoldLight,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: l10n.patientMyRequests),
            Tab(text: l10n.patientPurchased),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPatientGold))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: patientBodyStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _loadAll(),
                        style: FilledButton.styleFrom(backgroundColor: kPatientGoldDeep, foregroundColor: Colors.black),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _requestsTab(),
                    _purchasesTab(),
                  ],
                ),
    );
  }

  Widget _requestsTab() {
    final l10n = context.l10n;
    return RefreshIndicator(
      color: kPatientGold,
      backgroundColor: kPatientFieldFill,
      onRefresh: () => _loadAll(),
      child: _requests.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(
                    l10n.patientNoMedicationRequests,
                    style: patientBodyStyle(color: Colors.white54),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (_, i) => _requestCard(_requests[i]),
            ),
    );
  }

  Widget _purchasesTab() {
    final l10n = context.l10n;
    return RefreshIndicator(
      color: kPatientGold,
      backgroundColor: kPatientFieldFill,
      onRefresh: () => _loadAll(),
      child: _purchases.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(
                    l10n.patientNoPurchases,
                    style: patientBodyStyle(color: Colors.white54),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _purchases.length,
              itemBuilder: (_, i) => _purchaseCard(_purchases[i]),
            ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final l10n = context.l10n;
    final status = r['status']?.toString() ?? 'Pending';
    final display = _displayStatus(context, status);
    final updatedAt = DateTime.tryParse(r['updatedAt']?.toString() ?? r['createdAt']?.toString() ?? '');
    final color = _statusColor(status);
    final backorderQty = _backorderQty(r);
    final fulfilledQty = _fulfilledQty(r);
    final showBackorderAction = _hasBackorder(r) && backorderQty > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPatientFieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r['medicationName']?.toString() ?? l10n.patientMedication,
                  style: patientBodyStyle().copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  display,
                  style: GoogleFonts.urbanist(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row(
            Icons.shopping_bag_outlined,
            l10n.patientRequestedQty('${r['requestedQuantity'] ?? r['quantity'] ?? 1}'),
          ),
          if (fulfilledQty > 0)
            _row(Icons.check_circle_outline, l10n.patientFulfilledUnits(fulfilledQty)),
          if (backorderQty > 0)
            _row(Icons.hourglass_empty, l10n.patientBackorderUnits(backorderQty)),
          if (updatedAt != null)
            _row(Icons.update, l10n.patientUpdatedAt(_dateFmt.format(updatedAt.toLocal()))),
          if (r['notifyWhenInStock'] == true)
            _row(Icons.notifications_active_outlined, l10n.patientNotifyWhenInStock),
          if (showBackorderAction) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openNearbyForBackorder(r),
                icon: const Icon(Icons.map_outlined, color: kPatientGold, size: 20),
                label: Text(
                  l10n.patientFindRemainingNearby,
                  style: GoogleFonts.urbanist(
                    color: kPatientGoldLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: kPatientGold.withValues(alpha: 0.75), width: 1.4),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: kPatientGold.withValues(alpha: 0.06),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _purchaseCard(Map<String, dynamic> p) {
    final l10n = context.l10n;
    final isInternal = p['pharmacyType'] == 'Internal';
    final requiresRx = p['requiresPrescription'] == true;
    final doctor = p['prescribingDoctorName']?.toString() ?? p['doctorName']?.toString() ?? '';
    final purchasedAt = DateTime.tryParse(p['purchasedAt']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPatientFieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPatientGold.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPatientGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medication_outlined, color: kPatientGold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['drugName']?.toString() ?? l10n.patientMedication,
                      style: patientBodyStyle().copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    if ((p['dosage']?.toString() ?? '').isNotEmpty)
                      Text(p['dosage'].toString(), style: patientBodyStyle(color: Colors.white54, size: 13)),
                  ],
                ),
              ),
              if (requiresRx)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(l10n.patientRx, style: GoogleFonts.urbanist(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _row(Icons.local_pharmacy_outlined, p['pharmacyLabel']?.toString() ?? p['pharmacyName']?.toString() ?? ''),
          _row(
            Icons.store_mall_directory_outlined,
            isInternal ? l10n.patientClinicInternalPharmacy : l10n.patientExternalCommunityPharmacy,
          ),
          _row(Icons.shopping_bag_outlined, l10n.patientQty('${p['quantity'] ?? 1}')),
          if (purchasedAt != null)
            _row(Icons.calendar_today_outlined, _dateFmt.format(purchasedAt.toLocal())),
          if (requiresRx && doctor.isNotEmpty)
            _row(Icons.person_outline, l10n.patientPrescribingPhysician(doctor)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: kPatientGold.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: patientBodyStyle(color: Colors.white70, size: 13))),
        ],
      ),
    );
  }
}
