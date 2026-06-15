/// Parses doctor billing fields from API JSON (camelCase `consultationFee`).
class DoctorBillingProfile {
  const DoctorBillingProfile({
    required this.consultationFee,
    this.clinicName = '',
    this.currency = 'ILS',
  });

  static const double baselineFee = 100.0;

  final double consultationFee;
  final String clinicName;
  final String currency;

  /// Maps `consultationFee` from JSON — handles num, String, and null.
  static double parseConsultationFee(dynamic raw, {double fallback = baselineFee}) {
    if (raw == null) return fallback;
    if (raw is num) {
      final v = raw.toDouble();
      return v > 0 ? v : fallback;
    }
    final parsed = double.tryParse(raw.toString().trim());
    if (parsed != null && parsed > 0) return parsed;
    return fallback;
  }

  factory DoctorBillingProfile.fromJson(Map<String, dynamic> json) {
    return DoctorBillingProfile(
      consultationFee: parseConsultationFee(json['consultationFee']),
      clinicName: json['clinicName']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'ILS',
    );
  }

  String get displayedFeeLabel {
    final f = effectiveFee;
    return f.truncateToDouble() == f ? f.toInt().toString() : f.toStringAsFixed(2);
  }

  double get effectiveFee => consultationFee > 0 ? consultationFee : baselineFee;
}
