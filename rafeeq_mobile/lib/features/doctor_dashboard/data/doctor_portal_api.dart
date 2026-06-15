import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../api_config.dart';
import '../../../tenant_state.dart';
import '../../../utils/chat_message_helpers.dart';

class DoctorPortalApi {
  DoctorPortalApi._();

  static Map<String, String> _headers(String doctorId, {bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        'x-user-id': doctorId,
        if (TenantState.instance.orgId.isNotEmpty) 'x-org-id': TenantState.instance.orgId,
      };

  static Uri _u(String doctorId, String path) {
    final org = TenantState.instance.orgId;
    final base = Uri.parse('$rafeeqApiBase/api/doctor-portal/$doctorId$path');
    if (org.isEmpty) return base;
    return base.replace(queryParameters: {...base.queryParameters, 'orgId': org});
  }

  static Future<Map<String, dynamic>> getProfile(String doctorId) async {
    final r = await http.get(_u(doctorId, '/profile'), headers: _headers(doctorId));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> putProfile(String doctorId, Map<String, dynamic> body) async {
    final r = await http.put(
      _u(doctorId, '/profile'),
      headers: _headers(doctorId, json: true),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getClinicServices(String doctorId) async {
    final r = await http.get(_u(doctorId, '/clinic-services'), headers: _headers(doctorId));
    if (r.statusCode != 200) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  static Future<Map<String, dynamic>> putClinicServices(String doctorId, Map<String, dynamic> body) async {
    final r = await http.put(
      _u(doctorId, '/clinic-services'),
      headers: _headers(doctorId, json: true),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  static Future<List<dynamic>> getAppointments(String doctorId) async {
    final r = await http.get(_u(doctorId, '/appointments'), headers: _headers(doctorId));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> patchBooking(
    String doctorId,
    String appointmentId,
    String bookingStatus,
  ) async {
    final r = await http.patch(
      _u(doctorId, '/appointments/$appointmentId/booking'),
      headers: _headers(doctorId, json: true),
      body: jsonEncode({'bookingStatus': bookingStatus}),
    );
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> reschedule(
    String doctorId,
    String appointmentId,
    String date,
    String time,
  ) async {
    final r = await http.patch(
      _u(doctorId, '/appointments/$appointmentId/reschedule'),
      headers: _headers(doctorId, json: true),
      body: jsonEncode({'date': date, 'time': time}),
    );
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> patchVisit(
    String doctorId,
    String appointmentId,
    String status,
  ) async {
    final r = await http.patch(
      _u(doctorId, '/appointments/$appointmentId/visit'),
      headers: _headers(doctorId, json: true),
      body: jsonEncode({'status': status}),
    );
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getWaitingList(String doctorId) async {
    final r = await http.get(_u(doctorId, '/waiting-list'), headers: _headers(doctorId));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getPreconsult(String doctorId, String patientUserId) async {
    final r = await http.get(_u(doctorId, '/patient/$patientUserId/preconsult'), headers: _headers(doctorId));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getSession(String doctorId, String appointmentId) async {
    final r = await http.get(_u(doctorId, '/session/$appointmentId'), headers: _headers(doctorId));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> putSession(
    String doctorId,
    String appointmentId,
    Map<String, dynamic> body,
  ) async {
    final r = await http.put(
      _u(doctorId, '/session/$appointmentId'),
      headers: _headers(doctorId, json: true),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> postPrescription(
    String doctorId,
    Map<String, dynamic> body,
  ) async {
    final r = await http.post(
      _u(doctorId, '/prescriptions'),
      headers: _headers(doctorId, json: true),
      body: jsonEncode(body),
    );
    if (r.statusCode != 201) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getChatPatients(String doctorId) async {
    final r = await http.get(_u(doctorId, '/chat/patients'), headers: _headers(doctorId));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getChatMessages(String doctorId, String patientUserId) async {
    final r = await http.get(_u(doctorId, '/chat/$patientUserId/messages'), headers: _headers(doctorId));
    if (r.statusCode != 200) throw Exception('Chat load failed (${r.statusCode}): ${r.body}');
    final parsed = ChatMessageHelpers.parseList(jsonDecode(r.body));
    parsed.sort((a, b) {
      final ta = DateTime.tryParse(a['createdAt']?.toString() ?? a['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse(b['createdAt']?.toString() ?? b['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });
    return parsed;
  }

  static Future<void> postChatMessage(String doctorId, String patientUserId, String body) async {
    final r = await http.post(
      _u(doctorId, '/chat/$patientUserId/messages'),
      headers: _headers(doctorId, json: true),
      body: jsonEncode({'body': body}),
    );
    if (r.statusCode != 201) throw Exception('Chat send failed (${r.statusCode}): ${r.body}');
  }

  static Future<List<dynamic>> getReviews(String doctorId) async {
    final r = await http.get(_u(doctorId, '/reviews'), headers: _headers(doctorId));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getAnalytics(String doctorId) async {
    final r = await http.get(_u(doctorId, '/analytics'), headers: _headers(doctorId));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getNotifications(String doctorId) async {
    final r = await http.get(_u(doctorId, '/notifications'), headers: _headers(doctorId));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<void> markNotificationRead(String doctorId, String notificationId) async {
    final r = await http.patch(
      _u(doctorId, '/notifications/$notificationId/read'),
      headers: _headers(doctorId),
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }
}
