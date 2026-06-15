import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../api_config.dart';
import '../../../tenant_state.dart';
import '../../../utils/patient_user_id_utils.dart';
import '../../doctor_dashboard/data/doctor_portal_api.dart';
import '../../doctor_dashboard/data/doctor_session.dart';
import '../models/doctor_billing_profile.dart';

/// Doctor session billing — consultation fee deduction.
class BillingApi {
  BillingApi({required this.doctorUserId});

  final String doctorUserId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-user-id': doctorUserId,
        if (TenantState.instance.orgId.isNotEmpty) 'x-org-id': TenantState.instance.orgId,
        if (DoctorSession.instance.token.isNotEmpty)
          'Authorization': 'Bearer ${DoctorSession.instance.token}',
      };

  Uri _u(String path) => Uri.parse('$rafeeqApiBase/api/billing$path');

  dynamic _decodeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};
    dynamic decoded = jsonDecode(trimmed);
    if (decoded is String) {
      final inner = decoded.trim();
      if (inner.startsWith('{') || inner.startsWith('[')) {
        decoded = jsonDecode(inner);
      }
    }
    return decoded;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  /// Active consultation fee from `/api/billing/consultation-fee`.
  Future<double> consultationFee() async {
    final profile = await fetchConsultationProfile();
    return profile.effectiveFee;
  }

  /// Full billing profile with camelCase `consultationFee` mapping.
  Future<DoctorBillingProfile> fetchConsultationProfile() async {
    try {
      final r = await http.get(_u('/consultation-fee'), headers: _headers).timeout(const Duration(seconds: 15));
      if (r.statusCode < 400) {
        final body = _asMap(_decodeBody(r.body));
        if (body.isNotEmpty) {
          return DoctorBillingProfile.fromJson(body);
        }
      }
    } catch (_) {}

    // Fallback: doctor portal profile (same camelCase field on Doctors collection).
    try {
      final profile = await DoctorPortalApi.getProfile(doctorUserId);
      return DoctorBillingProfile.fromJson(profile);
    } catch (_) {}

    return const DoctorBillingProfile(consultationFee: DoctorBillingProfile.baselineFee);
  }

  Future<Map<String, dynamic>> deductSession({
    required String patientUserId,
    required double amount,
    String? appointmentId,
  }) async {
    final resolvedPatientId = mongoIdFromDynamic(patientUserId);
    if (resolvedPatientId.isEmpty) {
      throw BillingException(
        'Invalid patient identifier — cannot process billing.',
        code: 'INVALID_PATIENT_ID',
      );
    }

    final r = await http
        .post(
          _u('/deduct-session'),
          headers: _headers,
          body: jsonEncode({
            'patientUserId': resolvedPatientId,
            'patientId': resolvedPatientId,
            'amount': amount,
            if (appointmentId != null && appointmentId.isNotEmpty) 'appointmentId': appointmentId,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400) {
      try {
        final map = _asMap(_decodeBody(r.body));
        throw BillingException(
          map['message']?.toString() ?? r.body,
          code: map['code']?.toString(),
          walletBalance: DoctorBillingProfile.parseConsultationFee(map['walletBalance'], fallback: 0),
          required: DoctorBillingProfile.parseConsultationFee(map['required'], fallback: 0),
        );
      } catch (_) {
        throw Exception(r.body);
      }
    }
    return _asMap(_decodeBody(r.body));
  }
}

class BillingException implements Exception {
  BillingException(this.message, {this.code, this.walletBalance, this.required});
  final String message;
  final String? code;
  final double? walletBalance;
  final double? required;

  @override
  String toString() => message;
}
