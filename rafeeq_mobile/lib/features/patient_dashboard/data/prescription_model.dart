/// Electronic prescription (Rx) entity aligned with backend dispensing prescriptions.
class RxItem {
  RxItem({
    required this.medicationName,
    required this.quantityAllowed,
    this.quantityDispensed = 0,
    required this.instructions,
    this.drugId,
    this.itemId,
  });

  final String medicationName;
  final int quantityAllowed;
  int quantityDispensed;
  final String instructions;
  final String? drugId;
  final String? itemId;

  int get remainingPendingQuantity =>
      (quantityAllowed - quantityDispensed).clamp(0, quantityAllowed);

  bool get isFullyFulfilled => quantityDispensed >= quantityAllowed;

  RxItem copyWith({
    String? medicationName,
    int? quantityAllowed,
    int? quantityDispensed,
    String? instructions,
    String? drugId,
    String? itemId,
  }) {
    return RxItem(
      medicationName: medicationName ?? this.medicationName,
      quantityAllowed: quantityAllowed ?? this.quantityAllowed,
      quantityDispensed: quantityDispensed ?? this.quantityDispensed,
      instructions: instructions ?? this.instructions,
      drugId: drugId ?? this.drugId,
      itemId: itemId ?? this.itemId,
    );
  }

  factory RxItem.fromJson(Map<String, dynamic> json) {
    final allowed = (json['quantityAllowed'] as num?)?.toInt() ??
        (json['prescribedQuantity'] as num?)?.toInt() ??
        0;
    final dispensed = (json['quantityDispensed'] as num?)?.toInt() ??
        (json['dispensedQuantity'] as num?)?.toInt() ??
        0;

    return RxItem(
      medicationName: json['medicationName']?.toString() ?? 'Medication',
      quantityAllowed: allowed,
      quantityDispensed: dispensed,
      instructions: json['instructions']?.toString() ?? '',
      drugId: json['drugId']?.toString(),
      itemId: (json['id'] ?? json['_id'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'medicationName': medicationName,
        'quantityAllowed': quantityAllowed,
        'quantityDispensed': quantityDispensed,
        'instructions': instructions,
        if (drugId != null) 'drugId': drugId,
        if (itemId != null) 'id': itemId,
      };
}

class PrescriptionModel {
  PrescriptionModel({
    required this.prescriptionId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.createdAt,
    required this.medications,
    required this.electronicSignature,
    required this.isActive,
    this.backendId,
    this.status = 'Active',
    this.expiryDate,
  });

  final String prescriptionId;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final DateTime createdAt;
  final List<RxItem> medications;
  final String electronicSignature;
  final bool isActive;
  final String? backendId;
  final String status;
  final DateTime? expiryDate;

  bool get isFullyFulfilled =>
      medications.isNotEmpty && medications.every((item) => item.isFullyFulfilled);

  List<RxItem> get pendingMedications =>
      medications.where((item) => item.remainingPendingQuantity > 0).toList();

  List<String> get pendingDrugIds => pendingMedications
      .map((item) => item.drugId)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toList();

  List<String> get pendingMedicationNames =>
      pendingMedications.map((item) => item.medicationName).toList();

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    final medsRaw = json['medications'] as List<dynamic>? ??
        json['items'] as List<dynamic>? ??
        [];
    final medications = <RxItem>[
      for (final entry in medsRaw)
        if (entry is Map) RxItem.fromJson(Map<String, dynamic>.from(entry)),
    ];

    final createdRaw = json['createdAt'] ?? json['issueDate'];
    final createdAt = DateTime.tryParse(createdRaw?.toString() ?? '') ?? DateTime.now();
    final expiryRaw = json['expiryDate'];
    final expiryDate = expiryRaw == null ? null : DateTime.tryParse(expiryRaw.toString());

    final status = json['status']?.toString() ?? 'Active';
    final hasPending = medications.any((item) => item.remainingPendingQuantity > 0);
    final baseActive = json['isActive'] as bool? ?? (status == 'Active');
    final computedActive = baseActive && hasPending;

    return PrescriptionModel(
      prescriptionId: json['prescriptionId']?.toString() ??
          json['id']?.toString() ??
          'Rx-unknown',
      backendId: json['id']?.toString(),
      patientId: json['patientId']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      doctorId: json['doctorId']?.toString() ?? '',
      doctorName: json['doctorName']?.toString() ??
          json['prescribingDoctor']?.toString() ??
          'Physician',
      createdAt: createdAt,
      medications: medications,
      electronicSignature: json['electronicSignature']?.toString() ?? '',
      isActive: computedActive && !medications.every((item) => item.isFullyFulfilled),
      status: status,
      expiryDate: expiryDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'prescriptionId': prescriptionId,
        if (backendId != null) 'id': backendId,
        'patientId': patientId,
        'patientName': patientName,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'createdAt': createdAt.toIso8601String(),
        if (expiryDate != null) 'expiryDate': expiryDate!.toIso8601String(),
        'medications': medications.map((item) => item.toJson()).toList(),
        'electronicSignature': electronicSignature,
        'isActive': isActive,
        'status': status,
      };
}
