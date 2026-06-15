import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../api_config.dart';
import '../../../tenant_state.dart';
import 'org_admin_session.dart';

class OrgAdminApi {
  OrgAdminApi({required this.adminUserId});

  final String adminUserId;

  static final RegExp _objectIdPattern = RegExp(r'^[a-fA-F0-9]{24}$');

  static bool isValidObjectId(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return false;
    final lower = v.toLowerCase();
    if (lower == 'undefined' || lower == 'null') return false;
    return _objectIdPattern.hasMatch(v);
  }

  Map<String, String> _headersFor({String? clinicId}) {
    final resolvedClinicId = isValidObjectId(clinicId) ? clinicId!.trim() : null;
    final orgId = (OrgAdminSession.instance.orgId ?? TenantState.instance.orgId).trim();
    return {
      'Content-Type': 'application/json',
      'x-user-id': adminUserId,
      if (orgId.isNotEmpty) 'x-org-id': orgId,
      if (resolvedClinicId != null) 'x-clinic-id': resolvedClinicId,
    };
  }

  /// Resolves clinic scope from admin session, then tenant preference, then org clinics list.
  Future<String?> resolveAdminClinicId() async {
    final fromSession = OrgAdminSession.instance.clinicId?.trim() ?? '';
    if (isValidObjectId(fromSession)) return fromSession;

    final fromTenant = TenantState.instance.preferredClinicId.trim();
    if (isValidObjectId(fromTenant)) {
      await OrgAdminSession.instance.setClinicId(fromTenant);
      return fromTenant;
    }

    final orgId = (OrgAdminSession.instance.orgId ?? TenantState.instance.orgId).trim();
    if (!isValidObjectId(orgId)) return null;

    try {
      final r = await http
          .get(
            Uri.parse('$rafeeqApiBase/api/clinics').replace(queryParameters: {'orgId': orgId}),
            headers: _headersFor(),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode >= 400) return null;

      for (final clinic in asMapList(decodeBody(r.body))) {
        final id = clinic['_id']?.toString().trim() ?? '';
        if (isValidObjectId(id)) {
          await OrgAdminSession.instance.setClinicId(id);
          return id;
        }
      }
    } catch (e) {
      debugPrint('[OrgAdminApi] resolveAdminClinicId failed: $e');
    }
    return null;
  }

  Uri _u(String path, [Map<String, String>? q]) {
    final base = Uri.parse('$rafeeqApiBase/api/admin$path');
    if (q == null || q.isEmpty) return base;
    return base.replace(queryParameters: q);
  }

  /// Safely decodes HTTP bodies — handles empty payloads and double-encoded JSON strings.
  static dynamic decodeBody(String body) {
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

  static Map<String, dynamic> asMap(dynamic value, {Map<String, dynamic>? fallback}) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final inner = decodeBody(value);
        if (inner is Map) return Map<String, dynamic>.from(inner);
      } catch (_) {}
    }
    return fallback ?? <String, dynamic>{};
  }

  static List<Map<String, dynamic>> asMapList(dynamic value) {
    dynamic list = value;
    if (value is String) {
      try {
        list = decodeBody(value);
      } catch (_) {
        return [];
      }
    }
    if (list is! List) return [];
    return [
      for (final item in list)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  static double asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final r = await http.get(_u(path, query), headers: _headersFor()).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    return decodeBody(r.body);
  }

  Future<Map<String, dynamic>> getJsonMap(String path, {Map<String, String>? query}) async {
    final data = await getJson(path, query: query);
    return asMap(data);
  }

  Future<List<Map<String, dynamic>>> getJsonList(String path, {Map<String, String>? query}) async {
    final data = await getJson(path, query: query);
    return asMapList(data);
  }

  /// GET /api/appointments/clinic — read-only clinic appointment roster for org admin.
  Future<List<Map<String, dynamic>>> getClinicAppointments() async {
    final r = await http
        .get(Uri.parse('$rafeeqApiBase/api/appointments/clinic'), headers: _headersFor())
        .timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    return asMapList(decodeBody(r.body));
  }

  /// GET /api/admin/patients?clinicId= — clinic-scoped patient directory for org admin.
  Future<List<Map<String, dynamic>>> getClinicPatients() async {
    try {
      final clinicId = await resolveAdminClinicId();
      if (!isValidObjectId(clinicId)) {
        debugPrint(
          '[OrgAdminApi.getClinicPatients] Skipping request: clinicId is missing or invalid '
          '(value=${clinicId ?? 'null'}, adminUserId=$adminUserId, orgId=${OrgAdminSession.instance.orgId ?? TenantState.instance.orgId}).',
        );
        return [];
      }

      final uri = Uri.parse('$rafeeqApiBase/api/admin/patients').replace(
        queryParameters: {'clinicId': clinicId!},
      );
      final r = await http
          .get(uri, headers: _headersFor(clinicId: clinicId))
          .timeout(const Duration(seconds: 25));

      if (r.statusCode >= 400) {
        debugPrint('[OrgAdminApi.getClinicPatients] HTTP ${r.statusCode}: ${r.body}');
        return [];
      }
      return asMapList(decodeBody(r.body));
    } catch (e, st) {
      debugPrint('[OrgAdminApi.getClinicPatients] Error: $e\n$st');
      return [];
    }
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final r = await http.post(_u(path), headers: _headersFor(), body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty) return <String, dynamic>{};
    return decodeBody(r.body);
  }

  Future<Map<String, dynamic>> postJsonMap(String path, Map<String, dynamic> body) async {
    return asMap(await postJson(path, body));
  }

  Future<dynamic> putJson(String path, Map<String, dynamic> body) async {
    final r = await http.put(_u(path), headers: _headersFor(), body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  Future<dynamic> patchJson(String path, Map<String, dynamic> body) async {
    final r = await http.patch(_u(path), headers: _headersFor(), body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  Future<void> delete(String path) async {
    final r = await http.delete(_u(path), headers: _headersFor()).timeout(const Duration(seconds: 20));
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  // Legacy endpoints still on server root (not extended router)
  Future<List<dynamic>> legacyGet(String fullPath) async {
    final r = await http.get(Uri.parse('$rafeeqApiBase$fullPath'), headers: _headersFor()).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final data = jsonDecode(r.body);
    return data is List ? data : [];
  }

  Future<dynamic> legacyPost(String fullPath) async {
    final r = await http.post(Uri.parse('$rafeeqApiBase$fullPath'), headers: _headersFor()).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body);
  }

  Future<dynamic> legacyPostWithBody(String fullPath, Map<String, dynamic> body) async {
    final r = await http
        .post(Uri.parse('$rafeeqApiBase$fullPath'), headers: _headersFor(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> doctorAnalytics() async {
    final d = await getJson('/doctor-analytics');
    return asMap(d);
  }

  Future<dynamic> legacyPatch(String fullPath, Map<String, dynamic> body) async {
    final r = await http
        .patch(Uri.parse('$rafeeqApiBase$fullPath'), headers: _headersFor(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body);
  }
}
