class PharmacyDashboardStats {
  const PharmacyDashboardStats({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.totalDrugs,
    required this.availableDrugs,
    required this.lowStockItems,
    required this.outOfStockItems,
  });

  final String pharmacyId;
  final String pharmacyName;
  final int totalDrugs;
  final int availableDrugs;
  final int lowStockItems;
  final int outOfStockItems;

  factory PharmacyDashboardStats.fromJson(Map<String, dynamic> json) {
    return PharmacyDashboardStats(
      pharmacyId: json['pharmacyId']?.toString() ?? '',
      pharmacyName: json['pharmacyName']?.toString() ?? 'Pharmacy',
      totalDrugs: (json['totalDrugs'] as num?)?.toInt() ?? 0,
      availableDrugs: (json['availableDrugs'] as num?)?.toInt() ?? 0,
      lowStockItems: (json['lowStockItems'] as num?)?.toInt() ?? 0,
      outOfStockItems: (json['outOfStockItems'] as num?)?.toInt() ?? 0,
    );
  }
}

class PharmacyInventoryRow {
  PharmacyInventoryRow({
    required this.drugId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    required this.manufacturer,
    required this.status,
    this.expiryDate,
    this.requiresPrescription = false,
  });

  final String drugId;
  final String name;
  final String category;
  final int quantity;
  final double price;
  final String manufacturer;
  final String status;
  final DateTime? expiryDate;
  final bool requiresPrescription;

  factory PharmacyInventoryRow.fromJson(Map<String, dynamic> json) {
    final drug = json['drug'] as Map<String, dynamic>?;
    final expiry = json['expiryDate'];
    return PharmacyInventoryRow(
      drugId: (json['drug_id'] ?? drug?['id'] ?? drug?['_id'])?.toString() ?? '',
      name: drug?['name']?.toString() ?? 'Unknown',
      category: drug?['category']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      manufacturer: json['manufacturer']?.toString() ?? 'Rafeeq Pharma',
      status: json['status']?.toString() ?? 'Available',
      expiryDate: expiry != null ? DateTime.tryParse(expiry.toString()) : null,
      requiresPrescription: drug?['requiresPrescription'] == true || json['requiresPrescription'] == true,
    );
  }
}

class InventoryLogEntry {
  InventoryLogEntry({
    required this.action,
    required this.drugName,
    required this.quantityChange,
    required this.previousQty,
    required this.newQty,
    required this.createdAt,
  });

  final String action;
  final String drugName;
  final int quantityChange;
  final int previousQty;
  final int newQty;
  final DateTime? createdAt;

  factory InventoryLogEntry.fromJson(Map<String, dynamic> json) {
    return InventoryLogEntry(
      action: json['action']?.toString() ?? '',
      drugName: json['drugName']?.toString() ?? '',
      quantityChange: (json['quantityChange'] as num?)?.toInt() ?? 0,
      previousQty: (json['previousQty'] as num?)?.toInt() ?? 0,
      newQty: (json['newQty'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class MedicationRequestRow {
  MedicationRequestRow({
    required this.id,
    required this.medicationName,
    required this.quantity,
    required this.status,
    this.amount,
    this.paymentStatus,
    this.cardLastFour,
    this.failureReason,
    this.fulfilledQuantity,
    this.backorderQuantity,
  });

  final String id;
  final String medicationName;
  final int quantity;
  final String status;
  final double? amount;
  final String? paymentStatus;
  final String? cardLastFour;
  final String? failureReason;
  final int? fulfilledQuantity;
  final int? backorderQuantity;

  bool get isCompleted =>
      status == 'Paid' ||
      status == 'Approved' ||
      status == 'Dispensed' ||
      status == 'Partially Fulfilled';

  bool get isFailed => status == 'Failed';

  String get badgeLabel {
    if (status == 'Partially Fulfilled') return 'Partially Fulfilled';
    if (isCompleted) return 'Paid & Dispensed';
    if (isFailed) return 'Failed';
    if (status == 'Rejected') return 'Rejected';
    return status.isEmpty ? 'Pending' : status;
  }

  String? get transactionSubtitle {
    if (status == 'Partially Fulfilled' && (fulfilledQuantity ?? 0) > 0 && (backorderQuantity ?? 0) > 0) {
      return 'Fulfilled $fulfilledQuantity · Backorder $backorderQuantity units';
    }
    if (!isCompleted) return null;
    final amt = amount != null ? '${amount!.toStringAsFixed(2)} ILS' : 'Amount';
    final card = (cardLastFour ?? '').isNotEmpty ? ' · ****$cardLastFour' : '';
    return '$amt credited to wallet | Mock Success$card';
  }

  MedicationRequestRow copyWith({
    String? status,
    double? amount,
    String? paymentStatus,
    String? cardLastFour,
    String? failureReason,
  }) {
    return MedicationRequestRow(
      id: id,
      medicationName: medicationName,
      quantity: quantity,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      cardLastFour: cardLastFour ?? this.cardLastFour,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  factory MedicationRequestRow.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] is Map
        ? Map<String, dynamic>.from(json['payment'] as Map)
        : null;
    final split = json['split'] is Map ? Map<String, dynamic>.from(json['split'] as Map) : null;
    final rawAmount = json['amount'] ?? payment?['amount'];
    return MedicationRequestRow(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      medicationName: json['medicationName']?.toString() ?? '',
      quantity: (json['requestedQuantity'] as num?)?.toInt() ??
          (json['quantity'] as num?)?.toInt() ??
          1,
      status: json['status']?.toString() ?? 'Pending',
      amount: rawAmount != null ? (rawAmount as num).toDouble() : null,
      paymentStatus: payment?['status']?.toString(),
      cardLastFour: (json['cardLastFour'] ?? payment?['cardLastFour'])?.toString(),
      failureReason: json['failureReason']?.toString(),
      fulfilledQuantity: (json['fulfilledQuantity'] as num?)?.toInt() ?? (split?['fulfilledQuantity'] as num?)?.toInt(),
      backorderQuantity: (json['backorderQuantity'] as num?)?.toInt() ?? (split?['backorderQuantity'] as num?)?.toInt(),
    );
  }
}

class MedicationRequestPatchException implements Exception {
  MedicationRequestPatchException(this.message, this.request);
  final String message;
  final MedicationRequestRow request;

  @override
  String toString() => message;
}

class PharmacyAlert {
  PharmacyAlert({
    required this.type,
    required this.severity,
    required this.message,
  });

  final String type;
  final String severity;
  final String message;

  factory PharmacyAlert.fromJson(Map<String, dynamic> json) {
    return PharmacyAlert(
      type: json['type']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'info',
      message: json['message']?.toString() ?? '',
    );
  }
}
