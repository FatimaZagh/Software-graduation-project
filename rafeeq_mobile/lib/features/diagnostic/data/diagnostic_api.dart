import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../api_config.dart';
import '../../../tenant_state.dart';

/// Diagnostic orders API — technician queue, doctor inbox, patient results.
class DiagnosticApi {
  DiagnosticApi({required this.userId});

  final String userId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-user-id': userId,
        if (TenantState.instance.orgId.isNotEmpty) 'x-org-id': TenantState.instance.orgId,
      };

  Uri _tech(String path, [Map<String, String>? q]) {
    final base = Uri.parse('$rafeeqApiBase/api/diagnostic$path');
    if (q == null || q.isEmpty) return base;
    return base.replace(queryParameters: q);
  }

  Uri _doctor(String path, [Map<String, String>? q]) {
    final base = Uri.parse('$rafeeqApiBase/api/doctor$path');
    if (q == null || q.isEmpty) return base;
    return base.replace(queryParameters: q);
  }

  Future<List<Map<String, dynamic>>> pendingForRole(String role, {String? clinicId}) {
    final normalized = role.trim();
    if (normalized == 'Radiologist' ||
        normalized == 'Radiology Technologist' ||
        normalized == 'Radiology Technician' ||
        normalized == 'Radiology Tech') {
      return pendingRadiology(clinicId: clinicId);
    }
    return pendingLab(clinicId: clinicId);
  }

  Future<List<Map<String, dynamic>>> pendingLab({String? clinicId}) async {
    final q = clinicId != null && clinicId.isNotEmpty ? {'clinicId': clinicId} : null;
    final r = await http.get(_tech('/lab/pending', q), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final body = jsonDecode(r.body);
    if (body is! List) return [];
    return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> pendingRadiology({String? clinicId}) async {
    final q = clinicId != null && clinicId.isNotEmpty ? {'clinicId': clinicId} : null;
    final r = await http.get(_tech('/radiology/pending', q), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final body = jsonDecode(r.body);
    if (body is! List) return [];
    return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> completedForRole(String role, {String? clinicId}) {
    final normalized = role.trim();
    if (normalized == 'Radiologist' ||
        normalized == 'Radiology Technologist' ||
        normalized == 'Radiology Technician' ||
        normalized == 'Radiology Tech') {
      return completedRadiology(clinicId: clinicId);
    }
    return completedLab(clinicId: clinicId);
  }

  Future<List<Map<String, dynamic>>> completedLab({String? clinicId}) async {
    final q = clinicId != null && clinicId.isNotEmpty ? {'clinicId': clinicId} : null;
    final r = await http.get(_tech('/lab/completed', q), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final body = jsonDecode(r.body);
    if (body is! List) return [];
    return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> completedRadiology({String? clinicId}) async {
    final q = clinicId != null && clinicId.isNotEmpty ? {'clinicId': clinicId} : null;
    final r = await http.get(_tech('/radiology/completed', q), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final body = jsonDecode(r.body);
    if (body is! List) return [];
    return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> submitLab(String id, Map<String, dynamic> body) async {
    final r = await http.put(_tech('/lab/$id/submit'), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<Map<String, dynamic>> submitRadiology(String id, Map<String, dynamic> body) async {
    final r = await http.put(_tech('/radiology/$id/submit'), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<List<Map<String, dynamic>>> doctorCompletedLab() async {
    final r = await http.get(_doctor('/lab-results/completed'), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final body = jsonDecode(r.body);
    if (body is! List) return [];
    return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> doctorCompletedRadiology() async {
    final r = await http.get(_doctor('/radiology-results/completed'), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final body = jsonDecode(r.body);
    if (body is! List) return [];
    return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> unreadCounts() async {
    final r = await http.get(_doctor('/diagnostic-unread-counts'), headers: _headers).timeout(const Duration(seconds: 15));
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<void> markLabRead(String id) async {
    final r = await http.patch(_doctor('/lab-results/$id/read'), headers: _headers, body: '{}').timeout(const Duration(seconds: 15));
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<void> markRadiologyRead(String id) async {
    final r = await http.patch(_doctor('/radiology-results/$id/read'), headers: _headers).timeout(const Duration(seconds: 15));
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  static Future<List<Map<String, dynamic>>> patientResults(String patientUserId) async {
    final uri = Uri.parse('$rafeeqApiBase/api/patient-portal/$patientUserId/diagnostic-results');
    final r = await http.get(uri).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final body = jsonDecode(r.body);
    if (body is! List) return [];
    return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
