import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../api_config.dart';
import '../../../tenant_state.dart';

/// Thrown when nurse API returns an error response.
class NurseApiException implements Exception {
  NurseApiException(this.message, {this.code, this.statusCode = 0});

  final String message;
  final String? code;
  final int statusCode;

  bool get isPermissionDenied =>
      statusCode == 403 || code == 'NURSE_PERMISSION_DENIED';

  @override
  String toString() => message;

  static NurseApiException fromHttp(int statusCode, String body) {
    final trimmed = body.trim();
    if (trimmed.startsWith('<') || trimmed.startsWith('<!')) {
      return NurseApiException(
        statusCode == 404
            ? 'Lab orders endpoint not found. Restart the backend server and try again.'
            : 'Unexpected server response. Verify the API is running.',
        statusCode: statusCode,
      );
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return NurseApiException(
          decoded['message']?.toString().trim().isNotEmpty == true
              ? decoded['message'].toString()
              : 'Request failed',
          code: decoded['code']?.toString(),
          statusCode: statusCode,
        );
      }
    } catch (_) {}
    if (statusCode == 403) {
      return NurseApiException(
        'You do not have permission for this action.',
        code: 'NURSE_PERMISSION_DENIED',
        statusCode: 403,
      );
    }
    if (statusCode == 404) {
      return NurseApiException(
        'Lab orders endpoint not found.',
        statusCode: 404,
      );
    }
    return NurseApiException(
      trimmed.isNotEmpty ? trimmed : 'Request failed (HTTP $statusCode)',
      statusCode: statusCode,
    );
  }
}

class NursePortalApi {
  NursePortalApi({required this.nurseUserId});

  final String nurseUserId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-user-id': nurseUserId,
        if (TenantState.instance.orgId.isNotEmpty) 'x-org-id': TenantState.instance.orgId,
      };

  Uri _u(String path, [Map<String, String>? q]) {
    final base = Uri.parse('$rafeeqApiBase/api/nurse$path');
    if (q == null || q.isEmpty) return base;
    return base.replace(queryParameters: q);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final r = await http.get(_u(path, query), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw NurseApiException.fromHttp(r.statusCode, r.body);
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final r = await http.post(_u(path), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400) throw NurseApiException.fromHttp(r.statusCode, r.body);
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final r = await http.put(_u(path), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400) throw NurseApiException.fromHttp(r.statusCode, r.body);
    return jsonDecode(r.body);
  }

  Future<List<dynamic>> _decodeList(http.Response r) {
    if (r.body.isEmpty) return Future.value([]);
    final decoded = jsonDecode(r.body);
    return Future.value(decoded is List ? decoded : []);
  }

  static const _labRequestsBase = '/api/lab-requests';

  /// GET /api/lab-requests — pending doctor lab orders (labrequests collection).
  Future<List<dynamic>> incomingLabRequests() async {
    final r = await http
        .get(Uri.parse('$rafeeqApiBase$_labRequestsBase'), headers: _headers)
        .timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw NurseApiException.fromHttp(r.statusCode, r.body);
    return _decodeList(r);
  }

  /// PUT /api/lab-requests/:id/submit
  Future<Map<String, dynamic>> submitLabReport(String id, Map<String, dynamic> body) async {
    final r = await http
        .put(
          Uri.parse('$rafeeqApiBase$_labRequestsBase/$id/submit'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));
    if (r.statusCode >= 400) throw NurseApiException.fromHttp(r.statusCode, r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }
  Future<dynamic> putAuthProfileUpdate(Map<String, dynamic> body) async {
    final r = await http
        .put(
          Uri.parse('$rafeeqApiBase/api/auth/profile/update'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400) throw NurseApiException.fromHttp(r.statusCode, r.body);
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body);
  }
}

String nurseFriendlyError(Object e) {
  if (e is NurseApiException) {
    if (e.isPermissionDenied) {
      return 'You do not have access to this feature. Contact your clinic supervisor.';
    }
    return e.message;
  }
  return e.toString().replaceFirst('Exception: ', '');
}

bool nurseIsPermissionDenied(Object e) =>
    e is NurseApiException && e.isPermissionDenied;
