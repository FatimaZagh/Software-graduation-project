import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../../../api_config.dart';
import '../../../tenant_state.dart';
import '../../../utils/chat_message_helpers.dart';
import 'patient_backorder_item.dart';
import 'patient_medical_profile.dart';
import 'prescription_model.dart';

/// API client for `/api/patient-portal` (patientUserId = `users._id`).
class PatientPortalApi {
  PatientPortalApi._();
  static String get base => '$rafeeqApiBase/api/patient-portal';

  static Uri _withOrg(Uri uri) {
    final orgId = TenantState.instance.orgId.trim();
    if (orgId.isEmpty) return uri;
    final qp = <String, String>{...uri.queryParameters, 'orgId': orgId};
    return uri.replace(queryParameters: qp);
  }

  static Uri _u(String patientUserId, String path) => _withOrg(Uri.parse('$base/$patientUserId$path'));

  static Future<List<dynamic>> getSuggestedSlots(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/booking/suggest'));
    if (r.statusCode != 200) throw Exception(r.body);
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    return (m['nearestAvailable'] as List<dynamic>?) ?? [];
  }

  /// GET /api/clinics/:clinicId/doctors?orgId=
  static Future<List<Map<String, dynamic>>> getBookingDoctors(
    String clinicId, {
    String? orgId,
  }) async {
    final oid = (orgId ?? TenantState.instance.orgId).trim();
    final qp = <String, String>{};
    if (oid.isNotEmpty) qp['orgId'] = oid;
    final uri = Uri.parse('$rafeeqApiBase/api/clinics/$clinicId/doctors')
        .replace(queryParameters: qp);
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(r.body);
    final raw = jsonDecode(r.body);
    if (raw is! List) return [];
    return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
  }

  /// GET /api/doctors?orgId= — organization-wide roster (no clinic branch).
  static Future<List<Map<String, dynamic>>> getBookingDoctorsByOrg(String orgId) async {
    final oid = orgId.trim();
    if (oid.isEmpty) return [];
    final uri = Uri.parse('$rafeeqApiBase/api/doctors').replace(
      queryParameters: {'orgId': oid},
    );
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(r.body);
    final raw = jsonDecode(r.body);
    if (raw is! List) return [];
    return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
  }

  /// GET /api/appointments/available-dates?doctorId=&days=
  static Future<List<String>> getDoctorAvailableDates(
    String doctorUserId, {
    int days = 14,
  }) async {
    final uri = _withOrg(
      Uri.parse('$rafeeqApiBase/api/appointments/available-dates').replace(
        queryParameters: {
          'doctorId': doctorUserId,
          'doctorUserId': doctorUserId,
          'days': '$days',
        },
      ),
    );
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(r.body);
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    return [
      for (final d in (m['dates'] as List<dynamic>? ?? [])) d.toString(),
    ];
  }

  /// GET /api/appointments/doctor-active-days/:doctorId?days=
  /// Days where the doctor has at least one generated time slot.
  static Future<List<String>> getDoctorActiveDays(
    String doctorUserId, {
    int days = 60,
  }) async {
    final uri = _withOrg(
      Uri.parse('$rafeeqApiBase/api/appointments/doctor-active-days/$doctorUserId')
          .replace(queryParameters: {'days': '$days'}),
    );
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(r.body);
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    return [
      for (final d in (m['activeDates'] as List<dynamic>? ?? [])) d.toString(),
    ];
  }

  /// GET /api/appointments/slots?doctorId=&date=YYYY-MM-DD
  static Future<Map<String, dynamic>> getAppointmentSlots({
    required String doctorUserId,
    required String dateYmd,
  }) async {
    final uri = _withOrg(
      Uri.parse('$rafeeqApiBase/api/appointments/slots').replace(
        queryParameters: {
          'doctorId': doctorUserId,
          'doctorUserId': doctorUserId,
          'date': dateYmd,
        },
      ),
    );
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// GET /api/payments/saved-cards?patientUserId=
  static Future<List<Map<String, dynamic>>> getSavedPaymentCards(String patientUserId) async {
    final uri = _withOrg(
      Uri.parse('$rafeeqApiBase/api/payments/saved-cards').replace(
        queryParameters: {'patientUserId': patientUserId},
      ),
    );
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(parseErrorMessage(r.body));
    final decoded = jsonDecode(r.body);
    if (decoded is! Map) return [];
    final raw = decoded['cards'];
    if (raw is! List) return [];
    return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
  }

  /// POST /api/payments/checkout — CVV verified transiently; never stored server-side.
  static Future<Map<String, dynamic>> checkoutPaymentRaw({
    required String patientUserId,
    String? savedCardId,
    String? cvv,
    String? cardholderName,
    String? cardNumber,
    String? expirationDate,
    bool saveCard = true,
    String? medicineName,
    double? amount,
    String? orderId,
  }) async {
    final orgId = TenantState.instance.orgId.trim();
    final uri = _withOrg(Uri.parse('$rafeeqApiBase/api/payments/checkout'));
    final body = <String, dynamic>{
      'patientUserId': patientUserId,
      if (savedCardId != null && savedCardId.isNotEmpty) 'savedCardId': savedCardId,
      if (cvv != null && cvv.isNotEmpty) 'cvv': cvv,
      if (cardholderName != null && cardholderName.isNotEmpty) 'cardholderName': cardholderName,
      if (cardNumber != null && cardNumber.isNotEmpty) 'cardNumber': cardNumber,
      if (expirationDate != null && expirationDate.isNotEmpty) 'expirationDate': expirationDate,
      if (savedCardId == null || savedCardId.isEmpty) 'saveCard': saveCard,
      if (medicineName != null && medicineName.isNotEmpty) 'medicineName': medicineName,
      if (amount != null && amount > 0) 'amount': amount,
      if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
      if (orgId.isNotEmpty) 'orgId': orgId,
    };
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode >= 400) throw Exception(parseErrorMessage(r.body));
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  /// GET /api/patients/:id/my-bookings
  static Future<Map<String, dynamic>> getMyBookings(String patientUserId) async {
    final uri = _withOrg(Uri.parse('$rafeeqApiBase/api/patients/$patientUserId/my-bookings'));
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// GET /api/waiting-list/my-entries?patientUserId=
  static Future<List<Map<String, dynamic>>> getMyWaitingListEntries(String patientUserId) async {
    final uri = _withOrg(
      Uri.parse('$rafeeqApiBase/api/waiting-list/my-entries').replace(
        queryParameters: {'patientUserId': patientUserId},
      ),
    );
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded is! Map) return [];
    final raw = decoded['entries'] ?? decoded['waitingLists'];
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  /// PATCH /api/appointments/:id/cancel-by-patient
  static Future<Map<String, dynamic>> cancelAppointmentByPatient({
    required String patientUserId,
    required String appointmentId,
  }) async {
    final uri = _withOrg(Uri.parse('$rafeeqApiBase/api/appointments/$appointmentId/cancel-by-patient'));
    final r = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'patientUserId': patientUserId}),
    );
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// POST /api/appointments/book — returns body; `addedToWaitingList: true` when slot was full.
  static Future<Map<String, dynamic>> bookAppointment({
    required String patientUserId,
    required String patientName,
    required String dateYmd,
    required String timeHhmm,
    required String doctorUserId,
    required String doctorName,
    String? clinicId,
    String branch = '',
  }) async {
    final orgId = TenantState.instance.orgId.trim();
    final uri = _withOrg(Uri.parse('$rafeeqApiBase/api/appointments/book'));
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'patientUserId': patientUserId,
        'patientName': patientName,
        'date': dateYmd,
        'time': timeHhmm,
        'doctorUserId': doctorUserId,
        'doctorName': doctorName,
        if (clinicId != null && clinicId.isNotEmpty) 'clinicId': clinicId,
        if (branch.isNotEmpty) 'branch': branch,
        if (orgId.isNotEmpty) 'orgId': orgId,
      }),
    );
    if (r.statusCode != 201 && r.statusCode != 200) throw Exception(_parseApiMessage(r.body));
    final decoded = jsonDecode(r.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'appointment': decoded};
  }

  /// POST /api/appointments/slots/:slotId/waiting-list
  static Future<String> joinSlotWaitingList({
    required String patientUserId,
    required String slotId,
  }) async {
    final encoded = Uri.encodeComponent(slotId);
    final uri = _withOrg(
      Uri.parse('$rafeeqApiBase/api/appointments/slots/$encoded/waiting-list'),
    );
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'patientUserId': patientUserId, 'patientId': patientUserId}),
    );
    if (r.statusCode == 400) {
      throw Exception(_parseApiMessage(r.body));
    }
    if (r.statusCode != 201 && r.statusCode != 200) throw Exception(_parseApiMessage(r.body));
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    return m['message']?.toString() ?? 'Successfully added to the waiting list for this slot!';
  }

  static String _parseApiMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    final t = body.trim();
    return t.isEmpty ? 'Request failed' : t;
  }

  /// DELETE /api/waiting-list/leave/:entryId?patientUserId=
  static Future<void> leaveWaitingList({
    required String patientUserId,
    required String waitingListEntryId,
  }) async {
    final uri = _withOrg(
      Uri.parse('$rafeeqApiBase/api/waiting-list/leave/$waitingListEntryId').replace(
        queryParameters: {'patientUserId': patientUserId},
      ),
    );
    final r = await http.delete(uri);
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<void> joinWaitingList(
    String patientUserId, {
    String preferredDate = '',
    String preferredTime = '',
    String watchSlotDate = '',
    String watchSlotTime = '',
  }) async {
    final r = await http.post(
      _u(patientUserId, '/booking/waiting-list'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'preferredDate': preferredDate,
        'preferredTime': preferredTime,
        'watchSlotDate': watchSlotDate,
        'watchSlotTime': watchSlotTime,
      }),
    );
    if (r.statusCode != 201) throw Exception(r.body);
  }

  static String parseErrorMessage(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      return m['message']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }

  static Future<List<dynamic>> pharmacyCatalog(String patientUserId, String q) async {
    final baseUri = Uri.parse('$base/$patientUserId/pharmacy/catalog');
    final uri = _withOrg(
      baseUri.replace(queryParameters: q.isEmpty ? null : {'q': q}),
    );
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(parseErrorMessage(r.body));
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<List<dynamic>> pharmacySearch(String patientUserId, String q) async {
    try {
      return await pharmacyCatalog(patientUserId, q);
    } catch (_) {
      final baseUri = Uri.parse('$base/$patientUserId/pharmacy/search');
      final uri = _withOrg(
        baseUri.replace(queryParameters: q.isEmpty ? null : {'q': q}),
      );
      final r = await http.get(uri);
      if (r.statusCode != 200) throw Exception(parseErrorMessage(r.body));
      return jsonDecode(r.body) as List<dynamic>;
    }
  }

  static Future<Map<String, dynamic>> getPharmacyRouting(
    String patientUserId, {
    required String drugId,
    String? clinicId,
    double? lat,
    double? lng,
  }) async {
    final qp = <String, String>{'drugId': drugId};
    if (clinicId != null && clinicId.isNotEmpty) qp['clinicId'] = clinicId;
    if (lat != null) qp['lat'] = '$lat';
    if (lng != null) qp['lng'] = '$lng';
    final base = _u(patientUserId, '/pharmacy/routing');
    final uri = base.replace(queryParameters: {...base.queryParameters, ...qp});
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(parseErrorMessage(r.body));
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  /// Geospatial failover: external pharmacies holding [drugId] within [radiusKm].
  static Future<Map<String, dynamic>> searchPharmaciesByDrug({
    required String drugId,
    required double lat,
    required double lng,
    double radiusKm = 10,
    String? excludePharmacyId,
  }) async {
    final orgId = TenantState.instance.orgId.trim();
    final qp = <String, String>{
      'drugId': drugId,
      'lat': '$lat',
      'lng': '$lng',
      'radiusKm': '$radiusKm',
      if (orgId.isNotEmpty) 'orgId': orgId,
      if (excludePharmacyId != null && excludePharmacyId.isNotEmpty) 'excludePharmacyId': excludePharmacyId,
    };
    final uri = Uri.parse('$rafeeqApiBase/api/pharmacies/search-by-drug').replace(queryParameters: qp);
    final r = await http.get(uri).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception(parseErrorMessage(r.body));
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  static Future<List<dynamic>> getExternalPharmaciesHolding(
    String patientUserId, {
    required String drugId,
  }) async {
    final uri = _withOrg(Uri.parse('$base/$patientUserId/pharmacy/external-holding').replace(
      queryParameters: {'drugId': drugId},
    ));
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(parseErrorMessage(r.body));
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    return m['pharmacies'] as List<dynamic>? ?? [];
  }

  static Future<List<Map<String, dynamic>>> getMedicationRequests(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/pharmacy/requests'));
    if (r.statusCode != 200) throw Exception(parseErrorMessage(r.body));
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    final list = m['requests'] as List<dynamic>? ?? [];
    return [for (final e in list) if (e is Map) Map<String, dynamic>.from(e)];
  }

  static Future<List<PatientBackorderItem>> fetchActivePatientBackorders(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/pharmacy/backorders'));
    if (r.statusCode != 200) throw Exception(parseErrorMessage(r.body));
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    final list = m['backorders'] as List<dynamic>? ?? [];
    return [
      for (final e in list)
        if (e is Map) PatientBackorderItem.fromJson(Map<String, dynamic>.from(e)),
    ].where((item) => item.backorderQty > 0 && item.drugId.isNotEmpty).toList();
  }

  static Future<List<Map<String, dynamic>>> getPatientPurchases(String patientUserId) async {
    final uri = _withOrg(Uri.parse('$rafeeqApiBase/api/patient/purchases/$patientUserId'));
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(parseErrorMessage(r.body));
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    final list = m['purchases'] as List<dynamic>? ?? [];
    return [for (final e in list) if (e is Map) Map<String, dynamic>.from(e)];
  }

  static Future<Map<String, dynamic>> purchaseMedication(
    String patientUserId, {
    required String drugId,
    int quantity = 1,
    String? pharmacyId,
    String? paymentStatus,
    String? cardLastFour,
    String? cardholderName,
    String? locale,
    String? prescriptionId,
    String? medicationId,
  }) async {
    final orgId = TenantState.instance.orgId.trim();
    final r = await http.post(
      _u(patientUserId, '/pharmacy/purchase'),
      headers: {
        'Content-Type': 'application/json',
        if (locale != null && locale.isNotEmpty) 'x-locale': locale,
      },
      body: jsonEncode({
        'drugId': drugId,
        'quantity': quantity,
        if (orgId.isNotEmpty) 'orgId': orgId,
        if (pharmacyId != null && pharmacyId.isNotEmpty) 'pharmacyId': pharmacyId,
        if (paymentStatus != null && paymentStatus.isNotEmpty) 'paymentStatus': paymentStatus,
        if (cardLastFour != null && cardLastFour.isNotEmpty) 'cardLastFour': cardLastFour,
        if (cardholderName != null && cardholderName.isNotEmpty) 'cardholderName': cardholderName,
        if (locale != null && locale.isNotEmpty) 'patientLocale': locale,
        if (prescriptionId != null && prescriptionId.isNotEmpty) 'prescriptionId': prescriptionId,
        if (medicationId != null && medicationId.isNotEmpty) 'medicationId': medicationId,
      }),
    );
    if (r.statusCode >= 400) {
      throw Exception(parseErrorMessage(r.body));
    }
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  static Future<List<Map<String, dynamic>>> getDispensingPrescriptionsRaw(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/dispensing-prescriptions'));
    if (r.statusCode != 200) throw Exception(parseErrorMessage(r.body));
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    final list = m['prescriptions'] as List<dynamic>? ?? [];
    return [for (final e in list) if (e is Map) Map<String, dynamic>.from(e)];
  }

  static Future<List<PrescriptionModel>> getDispensingPrescriptions(String patientUserId) async {
    final raw = await getDispensingPrescriptionsRaw(patientUserId);
    return [for (final entry in raw) PrescriptionModel.fromJson(entry)];
  }

  static Future<List<dynamic>> nearbyPharmacies(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/pharmacy/nearby'));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<void> requestMedication(
    String patientUserId,
    String name, {
    bool notifyWhenInStock = false,
    String? drugId,
    int quantity = 1,
    required String pharmacyId,
  }) async {
    final orgId = TenantState.instance.orgId.trim();
    final r = await http.post(
      _u(patientUserId, '/pharmacy/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'medicationName': name,
        'pharmacyId': pharmacyId,
        'notifyWhenInStock': notifyWhenInStock,
        if (drugId != null && drugId.isNotEmpty) 'drugId': drugId,
        'quantity': quantity,
        if (orgId.isNotEmpty) 'orgId': orgId,
      }),
    );
    if (r.statusCode != 201) throw Exception(parseErrorMessage(r.body));
  }

  static Future<Map<String, dynamic>> getHealthProfile(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/health-profile'));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> putHealthProfile(
    String patientUserId,
    Map<String, dynamic> body,
  ) async {
    final r = await http.put(
      _u(patientUserId, '/health-profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getChatDoctors(String patientUserId, String clinicId) async {
    final r = await http.get(_u(patientUserId, '/chat/doctors?clinicId=$clinicId'));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Map<String, String> _headers({bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (TenantState.instance.orgId.isNotEmpty) 'x-org-id': TenantState.instance.orgId,
      };

  static Future<List<Map<String, dynamic>>> getChatMessages(String patientUserId, String doctorUserId) async {
    final r = await http.get(_u(patientUserId, '/chat/$doctorUserId/messages'), headers: _headers());
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

  static Future<void> sendChat(String patientUserId, String doctorUserId, String body) async {
    final r = await http.post(
      _u(patientUserId, '/chat/$doctorUserId/messages'),
      headers: _headers(json: true),
      body: jsonEncode({'body': body}),
    );
    if (r.statusCode != 201) throw Exception('Chat send failed (${r.statusCode}): ${r.body}');
  }

  static Future<List<dynamic>> getPrescriptions(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/prescriptions'));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<List<dynamic>> getLabs(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/labs'));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<void> postRating(
    String patientUserId, {
    required int cleanliness,
    required int punctuality,
    required int doctorBehavior,
    String comment = '',
  }) async {
    final r = await http.post(
      _u(patientUserId, '/ratings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cleanliness': cleanliness,
        'punctuality': punctuality,
        'doctorBehavior': doctorBehavior,
        'comment': comment,
      }),
    );
    if (r.statusCode != 201) throw Exception(r.body);
  }

  static Future<Map<String, dynamic>> chatbotAsk(
    String patientUserId, {
    String? message,
    String? question,
    String? currentMedication,
    String? medicationName,
  }) async {
    final body = <String, dynamic>{};
    final text = (message ?? question)?.trim();
    if (text != null && text.isNotEmpty) {
      body['message'] = text;
      body['question'] = text;
    }
    final med = (currentMedication ?? medicationName)?.trim();
    if (med != null && med.isNotEmpty) {
      body['currentMedication'] = med;
      body['medicationName'] = med;
    }
    if (body.isEmpty) {
      throw Exception('message (or question) or currentMedication required');
    }
    final r = await http.post(
      _u(patientUserId, '/chatbot/medications'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static String _preview(String value, int maxLen) {
    if (value.length <= maxLen) return value;
    return '${value.substring(0, maxLen)}…';
  }

  /// Rafeeq AI Medical Assistant — POST `$rafeeqApiBase/api/ai/chat` (default port 3000).
  static Future<String> postAiChat({
    required String message,
    Map<String, dynamic>? patientContext,
  }) async {
    final uri = Uri.parse('$rafeeqApiBase/api/ai/chat');
    final payload = <String, dynamic>{
      'message': message.trim(),
      if (patientContext != null) 'patientContext': patientContext,
    };

    debugPrint('[Rafeeq AI CLIENT] POST $uri');
    debugPrint('[Rafeeq AI CLIENT] Request body keys: ${payload.keys.toList()}');
    final trimmedMessage = message.trim();
    debugPrint(
      '[Rafeeq AI CLIENT] message preview: '
      '${trimmedMessage.isEmpty ? "EMPTY" : trimmedMessage.substring(0, trimmedMessage.length > 80 ? 80 : trimmedMessage.length)}',
    );

    late final http.Response r;
    try {
      r = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e, st) {
      debugPrint('[Rafeeq AI CLIENT] NETWORK_ERROR: $e');
      debugPrint('[Rafeeq AI CLIENT] NETWORK_ERROR stack: $st');
      rethrow;
    }

    debugPrint('[Rafeeq AI CLIENT] Response status: ${r.statusCode}');
    debugPrint('[Rafeeq AI CLIENT] Response body preview: ${_preview(r.body, 200)}');

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(r.body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      }
    } catch (e, st) {
      debugPrint('[Rafeeq AI CLIENT] JSON_DECODE_ERROR: $e');
      debugPrint('[Rafeeq AI CLIENT] JSON_DECODE_ERROR stack: $st');
      throw Exception(
        'AI endpoint returned non-JSON (${r.statusCode}) at $uri: ${r.body}',
      );
    }

    final reply = decoded?['reply']?.toString().trim();
    if (reply != null && reply.isNotEmpty) {
      debugPrint('[Rafeeq AI CLIENT] Parsed reply (${reply.length} chars)');
      if (reply.contains('internal healthcare service interruption')) {
        debugPrint('[Rafeeq AI CLIENT] WARNING: backend returned SERVICE_INTERRUPTED fallback');
      }
      return reply;
    }

    final error = decoded?['error']?.toString().trim();
    if (error != null && error.isNotEmpty) {
      debugPrint('[Rafeeq AI CLIENT] API error field: $error');
      throw Exception(error);
    }

    final unexpected = 'Unexpected AI response (${r.statusCode}) from $uri: ${r.body}';
    debugPrint('[Rafeeq AI CLIENT] VALIDATION_FAILURE: $unexpected');
    throw Exception(unexpected);
  }

  static Future<List<dynamic>> getReminders(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/reminders'));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<void> postReminder(
    String patientUserId,
    String medicineName,
    List<String> doseTimes,
  ) async {
    final r = await http.post(
      _u(patientUserId, '/reminders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'medicineName': medicineName, 'doseTimes': doseTimes}),
    );
    if (r.statusCode != 201) throw Exception(r.body);
  }

  static Future<void> logDoseTaken(
    String patientUserId,
    String reminderId,
    DateTime scheduledFor,
    {bool taken = true}
  ) async {
    final r = await http.post(
      Uri.parse('$base/$patientUserId/reminders/$reminderId/dose'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'scheduledFor': scheduledFor.toIso8601String(),
        'taken': taken,
      }),
    );
    if (r.statusCode != 200) throw Exception(r.body);
  }

  static Future<Map<String, dynamic>> getAnalytics(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/analytics'));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// GET /api/patient-portal/:patientUserId/medical-records — clinical baseline + encounter timeline.
  static Future<Map<String, dynamic>> getMedicalRecords(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/medical-records'));
    if (r.statusCode != 200) throw Exception(r.body);
    final raw = jsonDecode(r.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Unexpected medical records response');
    }
    return raw;
  }

  /// Typed medical profile for the Medical Records screen.
  static Future<PatientMedicalProfile> fetchPatientMedicalProfile(String patientUserId) async {
    final raw = await getMedicalRecords(patientUserId);
    return PatientMedicalProfile.fromJson(raw);
  }

  /// GET /api/payments/history?patientUserId= — checkout + pharmacy transaction log.
  static Future<Map<String, dynamic>> getPaymentHistory(String patientUserId) async {
    final uri = _withOrg(
      Uri.parse('$rafeeqApiBase/api/payments/history').replace(
        queryParameters: {'patientUserId': patientUserId},
      ),
    );
    final r = await http.get(uri);
    if (r.statusCode != 200) throw Exception(parseErrorMessage(r.body));
    final raw = jsonDecode(r.body);
    if (raw is! Map) throw Exception('Unexpected payment history response');
    return Map<String, dynamic>.from(raw);
  }

  static Future<List<dynamic>> getNotifications(String patientUserId) async {
    final r = await http.get(_u(patientUserId, '/notifications'));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  static Future<void> markNotificationRead(String patientUserId, String notificationId) async {
    final r = await http.patch(_u(patientUserId, '/notifications/$notificationId/read'));
    if (r.statusCode != 200) throw Exception(r.body);
  }
}
