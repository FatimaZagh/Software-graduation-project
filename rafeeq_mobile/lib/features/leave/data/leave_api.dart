import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../api_config.dart';
import '../../../tenant_state.dart';

class LeaveApiException implements Exception {
  LeaveApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class LeaveApi {
  LeaveApi({required this.userId});

  final String userId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-user-id': userId,
        if (TenantState.instance.orgId.isNotEmpty) 'x-org-id': TenantState.instance.orgId,
      };

  Uri _u(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$rafeeqApiBase/api/leaves$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: query);
  }

  static dynamic _decode(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return <dynamic>[];
    return jsonDecode(trimmed);
  }

  static List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) {
      return [
        for (final item in data)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
    return [];
  }

  static String _errorMessage(http.Response r) {
    try {
      final decoded = _decode(r.body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return 'Request failed (${r.statusCode})';
  }

  Future<List<Map<String, dynamic>>> fetchMyRequests() async {
    final r = await http.get(_u('/my-requests'), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw LeaveApiException(_errorMessage(r), statusCode: r.statusCode);
    return _asList(_decode(r.body));
  }

  Future<List<Map<String, dynamic>>> fetchAllRequests({String? status}) async {
    final q = status != null && status.trim().isNotEmpty ? {'status': status.trim()} : null;
    final r = await http.get(_u('/all', q), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw LeaveApiException(_errorMessage(r), statusCode: r.statusCode);
    return _asList(_decode(r.body));
  }

  Future<List<Map<String, dynamic>>> fetchHistory({required bool asOrgAdmin}) {
    return asOrgAdmin ? fetchAllRequests() : fetchMyRequests();
  }

  Future<Map<String, dynamic>> submitRequest({
    required String leaveType,
    required String reason,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final body = jsonEncode({
      'leaveType': leaveType,
      'reason': reason,
      'startDate': _ymd(startDate),
      'endDate': _ymd(endDate),
    });
    final r = await http.post(_u('/request'), headers: _headers, body: body).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw LeaveApiException(_errorMessage(r), statusCode: r.statusCode);
    final decoded = _decode(r.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'success': true};
  }

  Future<Map<String, dynamic>> updateStatus({
    required String requestId,
    required String status,
    String? rejectionReason,
  }) async {
    final body = jsonEncode({
      'status': status,
      if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
        'rejectionReason': rejectionReason.trim(),
    });
    final r = await http
        .put(_u('/$requestId/status'), headers: _headers, body: body)
        .timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw LeaveApiException(_errorMessage(r), statusCode: r.statusCode);
    final decoded = _decode(r.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'success': true};
  }

  static String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
