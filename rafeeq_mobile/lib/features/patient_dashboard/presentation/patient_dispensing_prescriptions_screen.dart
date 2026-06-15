import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n_extensions.dart';
import '../data/patient_navigation_bus.dart';
import '../data/patient_portal_api.dart';
import '../data/prescription_model.dart';
import 'patient_pharmacy_purchase_sheet.dart';
import 'patient_theme.dart';

/// Controlled electronic prescriptions with partial-fulfillment tracking.
class PatientDispensingPrescriptionsScreen extends StatefulWidget {
  const PatientDispensingPrescriptionsScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<PatientDispensingPrescriptionsScreen> createState() =>
      _PatientDispensingPrescriptionsScreenState();
}

class _PatientDispensingPrescriptionsScreenState extends State<PatientDispensingPrescriptionsScreen> {
  List<PrescriptionModel> _prescriptions = [];
  bool _loading = true;
  String? _error;

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
      final list = await PatientPortalApi.getDispensingPrescriptions(widget.patientUserId);
      if (mounted) setState(() => _prescriptions = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fulfillViaPharmacy(PrescriptionModel prescription) {
    if (!prescription.isActive || prescription.pendingMedications.isEmpty) return;

    final cartItems = prescription.pendingMedications.where((item) => (item.drugId ?? '').trim().isNotEmpty);
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientPrescribedMedsMissingCatalog)),
      );
      return;
    }

    PatientNavigationBus.dispatch(PatientNavigationIntent.fromPrescription(prescription));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.patientOpeningPharmacy(cartItems.length)),
        backgroundColor: kPatientGoldDeep,
        duration: const Duration(seconds: 2),
      ),
    );

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _openPurchaseForMedication(PrescriptionModel rx, RxItem item) async {
    if (!rx.isActive || item.isFullyFulfilled) return;

    final drugId = item.drugId?.trim() ?? '';
    if (drugId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientRxItemMissingDrugId)),
      );
      return;
    }

    final prescriptionOid = rx.backendId?.trim() ?? '';
    if (prescriptionOid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientPrescriptionIdMissing)),
      );
      return;
    }

    final purchased = await showPatientPharmacyPurchaseSheet(
      context,
      patientUserId: widget.patientUserId,
      drugId: drugId,
      drugName: item.medicationName,
      requiresPrescription: true,
      prescriptionId: prescriptionOid,
      medicationId: drugId,
      maxQuantity: item.remainingPendingQuantity,
    );

    if (purchased == true && mounted) {
      await _load();
    }
  }

  Color _statusColor(PrescriptionModel rx) {
    if (!rx.isActive) return const Color(0xFF42A5F5);
    switch (rx.status) {
      case 'Active':
        return const Color(0xFF4CAF50);
      case 'Completed':
        return const Color(0xFF42A5F5);
      case 'Expired':
        return const Color(0xFFE53935);
      case 'Cancelled':
        return Colors.grey;
      default:
        return Colors.white54;
    }
  }

  Widget _statusBadge(BuildContext context, PrescriptionModel rx) {
    final l10n = context.l10n;
    final label = rx.isActive
        ? l10n.patientStatusActive
        : (rx.isFullyFulfilled ? l10n.patientStatusCompleted : rx.status);
    final c = _statusColor(rx);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(color: c, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  String _fmtDate(BuildContext context, DateTime? dt) {
    if (dt == null) return context.l10n.patientEmDash;
    return DateFormat.yMMMd().format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: kPatientWorkspaceBlack,
      appBar: AppBar(
        backgroundColor: kPatientWorkspaceBlack,
        foregroundColor: kPatientGold,
        title: Text(l10n.patientEPrescriptions, style: patientTitleStyle(18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPatientGold))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: patientBodyStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: Text(l10n.retry)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: kPatientGold,
                  onRefresh: _load,
                  child: _prescriptions.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                l10n.patientNoEPrescriptions,
                                textAlign: TextAlign.center,
                                style: patientBodyStyle(color: Colors.white54),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _prescriptions.length,
                          itemBuilder: (_, i) {
                            final rx = _prescriptions[i];
                            final canOpenPharmacy = rx.isActive && rx.pendingMedications.isNotEmpty;

                            return Material(
                              color: Colors.transparent,
                              child: Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                    color: kPatientFieldFill,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: canOpenPharmacy
                                          ? kPatientGold.withValues(alpha: 0.45)
                                          : kPatientGold.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(rx.prescriptionId, style: patientTitleStyle(16)),
                                                const SizedBox(height: 4),
                                                Text(
                                                  rx.doctorName,
                                                  style: patientBodyStyle(color: kPatientGoldLight, size: 13),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _statusBadge(context, rx),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.patientIssuedExpires(
                                          _fmtDate(context, rx.createdAt),
                                          _fmtDate(context, rx.expiryDate),
                                        ),
                                        style: patientBodyStyle(color: Colors.white54, size: 13),
                                      ),
                                      if (rx.electronicSignature.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            l10n.patientESignature(rx.electronicSignature),
                                            style: patientBodyStyle(color: Colors.white38, size: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      const Divider(color: Colors.white12, height: 20),
                                      ...rx.medications.map((item) {
                                        final canPurchase =
                                            rx.isActive && !item.isFullyFulfilled && (item.drugId?.isNotEmpty == true);
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: canPurchase ? () => _openPurchaseForMedication(rx, item) : null,
                                              borderRadius: BorderRadius.circular(10),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            item.medicationName,
                                                            style: patientBodyStyle().copyWith(
                                                              fontWeight: FontWeight.w700,
                                                              decoration: canPurchase
                                                                  ? TextDecoration.underline
                                                                  : null,
                                                              decorationColor: kPatientGold.withValues(alpha: 0.5),
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.redAccent.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            l10n.patientRx,
                                                            style: GoogleFonts.urbanist(
                                                              color: Colors.redAccent,
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (item.instructions.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: Text(
                                                          item.instructions,
                                                          style: patientBodyStyle(color: Colors.white54, size: 12),
                                                        ),
                                                      ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      l10n.patientAllowedDispensedPending(
                                                        '${item.quantityAllowed}',
                                                        '${item.quantityDispensed}',
                                                        '${item.remainingPendingQuantity}',
                                                      ),
                                                      style: patientBodyStyle(color: Colors.white70, size: 13),
                                                    ),
                                                    if (item.isFullyFulfilled)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: Text(
                                                          l10n.patientFullyFulfilled,
                                                          style: patientBodyStyle(color: const Color(0xFF42A5F5), size: 12),
                                                        ),
                                                      )
                                                    else if (canPurchase)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.shopping_cart_outlined, color: kPatientGold, size: 16),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              l10n.patientTapToPurchaseRx,
                                                              style: patientBodyStyle(color: kPatientGoldLight, size: 12),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      if (canOpenPharmacy) ...[
                                        const SizedBox(height: 14),
                                        SizedBox(
                                          width: double.infinity,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => _fulfillViaPharmacy(rx),
                                              borderRadius: BorderRadius.circular(12),
                                              child: Ink(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  gradient: const LinearGradient(
                                                    colors: [kPatientGoldLight, kPatientGold],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: kPatientGold.withValues(alpha: 0.25),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.local_pharmacy, color: kPatientWorkspaceBlack, size: 20),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      l10n.patientOrderViaPharmacy,
                                                      style: GoogleFonts.urbanist(
                                                        color: kPatientWorkspaceBlack,
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            );
                          },
                        ),
                ),
    );
  }
}
