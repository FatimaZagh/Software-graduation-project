import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../api_config.dart';
import '../../../tenant_state.dart';
import 'pharmacist_session.dart';
import 'pharmacy_models.dart';

export 'pharmacy_models.dart';

class PharmacyInventoryApi {
  PharmacyInventoryApi({required this.userId, this.pharmacyId = ''});

  final String userId;
  final String pharmacyId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-user-id': userId,
        if (pharmacyId.isNotEmpty) 'x-pharmacy-id': pharmacyId,
        if (TenantState.instance.orgId.isNotEmpty) 'x-org-id': TenantState.instance.orgId,
        if (PharmacistSession.instance.token.isNotEmpty)
          'Authorization': 'Bearer ${PharmacistSession.instance.token}',
      };

  Uri _u(String path, [Map<String, String>? q]) {
    final base = Uri.parse('$rafeeqApiBase/api/pharmacy$path');
    if (q == null || q.isEmpty) return base;
    return base.replace(queryParameters: q);
  }

  Future<Map<String, dynamic>> getDashboardByUser() async {
    final r = await http.get(_u('/user/$userId/dashboard'), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode == 404) return {};
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<Map<String, dynamic>> createPharmacy({
    required String name,
    required double latitude,
    required double longitude,
    String status = 'Active',
  }) async {
    final r = await http
        .post(
          _u('/create'),
          headers: _headers,
          body: jsonEncode({
            'name': name,
            'latitude': latitude,
            'longitude': longitude,
            'status': status,
            'userId': userId,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<List<PharmacyInventoryRow>> listInventory(String pharmacyId, {int limit = 200}) async {
    final r = await http.get(_u('/$pharmacyId/inventory', {'limit': '$limit'}), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final data = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => PharmacyInventoryRow.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Map<String, dynamic>> dispense({
    required String pharmacyId,
    required String drugId,
    int amount = 1,
    String? patientUserId,
  }) async {
    final r = await http
        .post(
          _u('/$pharmacyId/dispense'),
          headers: _headers,
          body: jsonEncode({
            'drugId': drugId,
            'amount': amount,
            if (patientUserId != null && patientUserId.isNotEmpty) 'patientUserId': patientUserId,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) {
      try {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        throw Exception(m['message']?.toString() ?? r.body);
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception(r.body);
      }
    }
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<Map<String, dynamic>> updateInventory(
    String pharmacyId,
    String drugId, {
    int? quantity,
    double? price,
    String? manufacturer,
    String? expiryDate,
  }) async {
    final body = <String, dynamic>{};
    if (quantity != null) body['quantity'] = quantity;
    if (price != null) body['price'] = price;
    if (manufacturer != null) body['manufacturer'] = manufacturer;
    if (expiryDate != null) body['expiryDate'] = expiryDate;

    final r = await http.patch(_u('/$pharmacyId/inventory/$drugId'), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<Map<String, dynamic>> deleteInventory(String pharmacyId, String drugId) async {
    final r = await http.delete(_u('/$pharmacyId/inventory/$drugId'), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<Map<String, dynamic>> createNewInventoryDrug(
    String pharmacyId, {
    required String name,
    required String category,
    required int quantity,
    required double price,
    required String manufacturer,
    required String expiryDate,
    bool requiresPrescription = false,
  }) async {
    final r = await http
        .post(
          _u('/$pharmacyId/inventory/new-drug'),
          headers: _headers,
          body: jsonEncode({
            'name': name,
            'category': category,
            'quantity': quantity,
            'price': price,
            'manufacturer': manufacturer,
            'expiryDate': expiryDate,
            'requiresPrescription': requiresPrescription,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<List<InventoryLogEntry>> getInventoryLogs(String pharmacyId) async {
    final r = await http.get(_u('/$pharmacyId/inventory-logs'), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final data = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    final logs = data['logs'] as List<dynamic>? ?? [];
    return logs.map((e) => InventoryLogEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<PharmacyAlert>> getNotifications(String pharmacyId) async {
    final r = await http.get(_u('/$pharmacyId/notifications'), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final data = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    final alerts = data['alerts'] as List<dynamic>? ?? [];
    return alerts.map((e) => PharmacyAlert.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Map<String, dynamic>> getAnalytics(String pharmacyId) async {
    final r = await http.get(_u('/$pharmacyId/analytics'), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<Map<String, dynamic>> updateSettings(String pharmacyId, Map<String, dynamic> settings) async {
    final r = await http.patch(_u('/$pharmacyId/settings'), headers: _headers, body: jsonEncode(settings)).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  /// Persists pharmacy profile, address, and map coordinates.
  Future<Map<String, dynamic>> updatePharmacyProfile(String pharmacyId, Map<String, dynamic> profile) async {
    final r = await http.put(_u('/profile'), headers: _headers, body: jsonEncode(profile)).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final r = await http.get(_u('/user/$userId/profile'), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<Map<String, dynamic>> updatePharmacistProfile({
    required String name,
    required String email,
    required String phone,
    String? profileImageUrl,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
    };
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      body['profileImageUrl'] = profileImageUrl;
    }
    final r = await http.put(_u('/pharmacist/profile'), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400) throw Exception(r.body);
    final data = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    return Map<String, dynamic>.from((data['profile'] ?? data) as Map);
  }

  Future<List<MedicationRequestRow>> listMedicationRequests({String? status, String? pharmacyId}) async {
    final pid = (pharmacyId ?? this.pharmacyId).trim();
    final q = <String, String>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (pid.isNotEmpty) 'pharmacyId': pid,
    };
    final r = await http
        .get(_u('/medication-requests', q.isEmpty ? null : q), headers: _headers)
        .timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final data = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    final requests = data['requests'] as List<dynamic>? ?? [];
    return requests.map((e) => MedicationRequestRow.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<MedicationRequestRow> patchMedicationRequest(String requestId, String status) async {
    final r = await http
        .patch(_u('/medication-requests/$requestId'), headers: _headers, body: jsonEncode({'status': status}))
        .timeout(const Duration(seconds: 30));
    final data = r.body.isNotEmpty
        ? Map<String, dynamic>.from(jsonDecode(r.body) as Map)
        : <String, dynamic>{};
    if (r.statusCode >= 400) {
      final requestJson = data['request'];
      if (requestJson is Map) {
        throw MedicationRequestPatchException(
          data['message']?.toString() ?? r.body,
          MedicationRequestRow.fromJson(Map<String, dynamic>.from(requestJson)),
        );
      }
      throw Exception(data['message']?.toString() ?? r.body);
    }
    final requestJson = data['request'] ?? data;
    if (requestJson is! Map) {
      return MedicationRequestRow(
        id: requestId,
        medicationName: '',
        quantity: 1,
        status: status,
      );
    }
    final merged = Map<String, dynamic>.from(requestJson);
    if (data['payment'] is Map) merged['payment'] = data['payment'];
    if (data['split'] is Map) merged['split'] = data['split'];
    return MedicationRequestRow.fromJson(merged);
  }

  Future<List<Map<String, dynamic>>> listGlobalDrugs() async {
    final r = await http.get(_u('/drugs'), headers: _headers).timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) throw Exception(r.body);
    final data = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    final drugs = data['drugs'] as List<dynamic>? ?? [];
    return drugs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

/// Sidebar / module index for Medication Requests (pharmacist shell).
const int kPharmacistMedicationRequestsNavIndex = 4;

/// Shared workspace state passed to module views.
class PharmacyWorkspace {
  PharmacyWorkspace({
    required this.api,
    required this.userId,
    required this.pharmacyId,
    required this.stats,
    required this.onRefresh,
    ValueNotifier<int>? inventoryRevision,
    ValueNotifier<int>? pendingMedicationRequests,
    this.sectionIndex,
  })  : inventoryRevision = inventoryRevision ?? ValueNotifier(0),
        pendingMedicationRequests = pendingMedicationRequests ?? ValueNotifier(0);

  final PharmacyInventoryApi api;
  final String userId;
  String pharmacyId;
  PharmacyDashboardStats stats;
  final Future<void> Function() onRefresh;

  /// Bumped after inventory mutations so analytics can reload in place.
  final ValueNotifier<int> inventoryRevision;

  /// Live count of patient orders awaiting pharmacist action (`Pending`).
  final ValueNotifier<int> pendingMedicationRequests;

  /// Shell navigation — set when workspace is owned by [PharmacistEnterpriseShell].
  final ValueNotifier<int>? sectionIndex;

  void openMedicationRequests() {
    sectionIndex?.value = kPharmacistMedicationRequestsNavIndex;
  }

  Future<void> refreshPendingMedicationRequests() async {
    try {
      final pending = await api.listMedicationRequests(
        status: 'Pending',
        pharmacyId: pharmacyId,
      );
      pendingMedicationRequests.value = pending.length;
    } catch (_) {
      // Keep last known count on transient network errors.
    }
  }

  void applyDashboardFromResponse(Map<String, dynamic> res) {
    final dash = res['dashboard'];
    if (dash is Map<String, dynamic>) {
      stats = PharmacyDashboardStats.fromJson(dash);
    }
  }

  Future<void> refreshAfterInventoryChange({Map<String, dynamic>? apiResponse}) async {
    if (apiResponse != null) applyDashboardFromResponse(apiResponse);
    await onRefresh();
    inventoryRevision.value++;
  }
}
