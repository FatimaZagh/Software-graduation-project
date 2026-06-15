import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'platform_super_admin_session.dart';

class SuperAdminApi {
  SuperAdminApi._();

  static Map<String, String> get _headers => {
    'Authorization': 'Bearer ${PlatformSuperAdminSession.token}',
    'Content-Type': 'application/json',
  };

  static Uri _u(String path) => Uri.parse('$rafeeqApiBase/api/superadmin$path');

  static Future<List<Map<String, dynamic>>> getOrganizations({String? status}) async {
    final uri = status == null ? _u('/organizations') : _u('/organizations').replace(queryParameters: {'status': status});
    final r = await http.get(uri, headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
    return _list(r.body);
  }

  static Future<List<Map<String, dynamic>>> getPendingOrganizations() async {
    final r = await http.get(_u('/pending-orgs'), headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
    return _list(r.body);
  }

  static Future<Map<String, dynamic>> getOrganizationDetail(String orgId) async {
    final r = await http.get(_u('/organizations/$orgId'), headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
    return _map(r.body);
  }

  static Future<Map<String, dynamic>> getOrganizationStaff(String orgId) async {
    final r = await http.get(_u('/organizations/$orgId/staff'), headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
    return _map(r.body);
  }

  static Future<Map<String, dynamic>> getStaffMember(String orgId, String userId) async {
    final r = await http.get(_u('/organizations/$orgId/staff/$userId'), headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
    return _map(r.body);
  }

  static Future<void> updateStaffMember(
    String orgId,
    String userId,
    Map<String, dynamic> body,
  ) async {
    final r = await http.put(
      _u('/organizations/$orgId/staff/$userId'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> updateStaffStatus(
    String orgId,
    String userId, {
    String? status,
    bool delete = false,
  }) async {
    final r = await http.patch(
      _u('/organizations/$orgId/staff/$userId/status'),
      headers: _headers,
      body: jsonEncode({
        if (status != null) 'status': status,
        'delete': delete,
      }),
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> approveOrganization(String orgId) async {
    final r = await http.post(_u('/approve-org/$orgId'), headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> rejectOrganization(String orgId, {String? reason}) async {
    final r = await http.post(
      _u('/organizations/$orgId/reject'),
      headers: _headers,
      body: jsonEncode({if (reason != null && reason.isNotEmpty) 'reason': reason}),
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> approvePendingRegistration(String requestId) async {
    final r = await http.post(
      _u('/pending-registrations/$requestId/approve'),
      headers: _headers,
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> rejectPendingRegistration(String requestId) async {
    final r = await http.post(
      _u('/pending-registrations/$requestId/reject'),
      headers: _headers,
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> approvePendingStaff(String userId) async {
    final r = await http.post(_u('/pending-staff/$userId/approve'), headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> rejectPendingStaff(String userId) async {
    final r = await http.post(_u('/pending-staff/$userId/reject'), headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<Map<String, dynamic>> getPendingApplications() async {
    final r = await http.get(_u('/pending-applications'), headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
    return _map(r.body);
  }

  static Future<Map<String, dynamic>> getFinancialLedger() async {
    final r = await http.get(_u('/financial-ledger'), headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
    return _map(r.body);
  }

  /// Aggregated lab, imaging, and e-prescription activity across all facilities.
  static Future<Map<String, dynamic>> getMedicalOrdersFeed({int? limit}) async {
    final uri = limit == null
        ? _u('/medical-orders-feed')
        : _u('/medical-orders-feed').replace(queryParameters: {'limit': '$limit'});
    final r = await http.get(uri, headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
    return _map(r.body);
  }

  static Future<Map<String, dynamic>> getPharmacyDetails(String pharmacyId) async {
    final r = await http.get(_u('/pharmacies/$pharmacyId/details'), headers: _headers);
    if (r.statusCode != 200) throw Exception(r.body);
    return _map(r.body);
  }

  static List<Map<String, dynamic>> _list(String body) {
    final raw = jsonDecode(body);
    if (raw is Map<String, dynamic>) {
      if (raw['data'] is List) {
        return [
          for (final e in raw['data'] as List)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
      }
    }
    if (raw is List) {
      return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
    }
    throw Exception('Invalid list response: $body');
  }

  static Map<String, dynamic> _map(String body) {
    final raw = jsonDecode(body);
    if (raw is! Map<String, dynamic>) throw Exception('Invalid map response');
    if (raw['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    if (raw['allOrders'] is List) {
      return raw;
    }
    return raw;
  }
}
