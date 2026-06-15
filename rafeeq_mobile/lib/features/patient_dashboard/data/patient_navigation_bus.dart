import 'package:flutter/foundation.dart';

import 'prescription_model.dart';

/// Line item pre-loaded into the pharmacy cart from an active e-prescription.
class PrescriptionCartItem {
  const PrescriptionCartItem({
    required this.drugId,
    required this.medicationName,
    this.quantity = 1,
    this.maxQuantity,
    this.prescriptionItemId,
  });

  final String drugId;
  final String medicationName;
  final int quantity;
  final int? maxQuantity;
  final String? prescriptionItemId;
}

/// Deep-link intent dispatched when a patient taps an in-app notification or Rx row.
class PatientNavigationIntent {
  const PatientNavigationIntent({
    required this.type,
    required this.drugId,
    this.drugName,
    this.pharmacyId,
    this.requestId,
    this.notificationId,
    this.backorderQuantity,
    this.fulfilledQuantity,
    this.openPurchaseSheet = true,
    this.filterDrugIds = const [],
    this.filterMedicationNames = const [],
    this.prescriptionId,
    this.isFromPrescription = false,
    this.cartItems = const [],
  });

  final String type;
  final String drugId;
  final String? drugName;
  final String? pharmacyId;
  final String? requestId;
  final String? notificationId;
  final int? backorderQuantity;
  final int? fulfilledQuantity;
  final bool openPurchaseSheet;
  final List<String> filterDrugIds;
  final List<String> filterMedicationNames;
  final String? prescriptionId;
  final bool isFromPrescription;
  final List<PrescriptionCartItem> cartItems;

  bool get isPartialFulfillment =>
      type == 'PARTIAL_FULFILLMENT' ||
      (backorderQuantity != null && backorderQuantity! > 0);

  bool get isPrescriptionPharmacyFilter => type == 'PRESCRIPTION_PHARMACY';

  bool get isPharmacyDeepLink {
    if (isFromPrescription) return true;
    if (isPrescriptionPharmacyFilter) {
      return filterDrugIds.isNotEmpty ||
          filterMedicationNames.isNotEmpty ||
          drugId.isNotEmpty ||
          (prescriptionId != null && prescriptionId!.trim().isNotEmpty);
    }
    return drugId.isNotEmpty && isPartialFulfillment;
  }

  static bool isPartialFulfillmentNotification(Map<String, dynamic> notification) {
    final type = notification['type']?.toString().toUpperCase() ?? '';
    if (type == 'PARTIAL_FULFILLMENT') return true;

    final meta = notification['meta'];
    if (meta is! Map) return false;
    final m = Map<String, dynamic>.from(meta);
    final action = m['action']?.toString().toUpperCase() ?? '';
    if (action == 'PARTIAL_FULFILLMENT') return true;

    final status = m['status']?.toString() ?? '';
    if (status == 'Backorder' || status == 'Partially Fulfilled') return true;

    return (m['backorderQuantity'] as num?)?.toInt() != null &&
        ((m['backorderQuantity'] as num).toInt() > 0);
  }

  static PatientNavigationIntent? fromNotification(Map<String, dynamic> notification) {
    if (!isPartialFulfillmentNotification(notification)) return null;

    final metaRaw = notification['meta'];
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final drugId = meta['drugId']?.toString() ?? '';
    if (drugId.isEmpty) return null;

    return PatientNavigationIntent(
      type: 'PARTIAL_FULFILLMENT',
      drugId: drugId,
      drugName: meta['medicationName']?.toString(),
      pharmacyId: meta['pharmacyId']?.toString(),
      requestId: meta['requestId']?.toString(),
      notificationId: notification['_id']?.toString() ?? notification['id']?.toString(),
      backorderQuantity: (meta['backorderQuantity'] as num?)?.toInt(),
      fulfilledQuantity: (meta['fulfilledQuantity'] as num?)?.toInt(),
    );
  }

  static PatientNavigationIntent fromPrescription(PrescriptionModel prescription) {
    final pending = prescription.pendingMedications;
    final drugIds = prescription.pendingDrugIds;
    final names = prescription.pendingMedicationNames;
    final primary = pending.isNotEmpty ? pending.first : null;
    final prescriptionOid = prescription.backendId?.trim().isNotEmpty == true
        ? prescription.backendId!.trim()
        : prescription.prescriptionId.trim();

    return PatientNavigationIntent(
      type: 'PRESCRIPTION_PHARMACY',
      drugId: primary?.drugId ?? (drugIds.isNotEmpty ? drugIds.first : ''),
      drugName: primary?.medicationName ?? (names.isNotEmpty ? names.first : null),
      prescriptionId: prescriptionOid,
      filterDrugIds: drugIds,
      filterMedicationNames: names,
      isFromPrescription: true,
      openPurchaseSheet: false,
      cartItems: [
        for (final item in pending)
          if ((item.drugId ?? '').trim().isNotEmpty)
            PrescriptionCartItem(
              drugId: item.drugId!.trim(),
              medicationName: item.medicationName,
              quantity: 1,
              maxQuantity: item.remainingPendingQuantity,
              prescriptionItemId: item.itemId,
            ),
      ],
    );
  }
}

/// Global bus: shell switches tabs; [PatientPharmacyTab] consumes pharmacy intents.
class PatientNavigationBus {
  PatientNavigationBus._();

  static final ValueNotifier<PatientNavigationIntent?> pending = ValueNotifier(null);

  static void dispatch(PatientNavigationIntent intent) {
    pending.value = intent;
  }

  static void clear() {
    pending.value = null;
  }
}
