class PatientBackorderItem {
  const PatientBackorderItem({
    required this.id,
    required this.drugId,
    required this.medicationName,
    required this.fulfilledQty,
    required this.backorderQty,
    this.pharmacyId,
    this.requestId,
  });

  final String id;
  final String drugId;
  final String medicationName;
  final int fulfilledQty;
  final int backorderQty;
  final String? pharmacyId;
  final String? requestId;

  factory PatientBackorderItem.fromJson(Map<String, dynamic> json) {
    final lines = json['lineItems'] as List<dynamic>? ?? [];
    int backorderFromLines = 0;
    int fulfilledFromLines = 0;
    for (final raw in lines) {
      if (raw is! Map) continue;
      final line = Map<String, dynamic>.from(raw);
      final type = line['lineType']?.toString() ?? '';
      final status = line['status']?.toString() ?? '';
      final qty = (line['quantity'] as num?)?.toInt() ?? 0;
      if (type == 'Backorder' || status == 'Backorder' || status == 'Awaiting Stock') {
        backorderFromLines = qty;
      }
      if (type == 'Fulfilled' || status == 'Paid' || status == 'Fulfilled') {
        fulfilledFromLines = qty;
      }
    }

    final requested = (json['requestedQuantity'] as num?)?.toInt() ??
        (json['quantity'] as num?)?.toInt() ??
        0;
    final backorderQty = (json['backorderQuantity'] as num?)?.toInt() ?? backorderFromLines;
    final fulfilledRaw = (json['fulfilledQuantity'] as num?)?.toInt();
    final fulfilledQty = fulfilledRaw != null && fulfilledRaw > 0
        ? fulfilledRaw
        : (fulfilledFromLines > 0
            ? fulfilledFromLines
            : (requested > backorderQty ? requested - backorderQty : 0));

    return PatientBackorderItem(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      drugId: json['drugId']?.toString() ?? '',
      medicationName: json['medicationName']?.toString() ?? 'Medication',
      fulfilledQty: fulfilledQty,
      backorderQty: backorderQty,
      pharmacyId: json['pharmacyId']?.toString(),
      requestId: (json['_id'] ?? json['id'])?.toString(),
    );
  }
}
