import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../api_config.dart';

/// Fetches and filters clinic branches for clinical technologist registration.
abstract final class ClinicalSignupClinicsApi {
  static const _labServices = {'laboratory', 'clinical lab'};
  static const _radioServices = {'radiology', 'x-ray', 'xray'};

  static Future<List<Map<String, dynamic>>> fetchClinicsForOrg(
    String orgId, {
    required bool forLabTechnician,
  }) async {
    final trimmed = orgId.trim();
    if (trimmed.isEmpty) return [];

    final capability = forLabTechnician ? 'laboratory' : 'radiology';
    final uri = Uri.parse('$rafeeqApiBase/api/clinics').replace(
      queryParameters: {'orgId': trimmed, 'capability': capability},
    );

    final r = await http.get(uri).timeout(const Duration(seconds: 15));

    if (r.statusCode != 200) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Clinics fetch failed: HTTP ${r.statusCode} — ${r.body}');
      }
      return [];
    }

    final body = jsonDecode(r.body);
    if (body is! List) return [];

    final clinicsList = body
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((c) => c['_id'] != null && c['name']?.toString().trim().isNotEmpty == true)
        .toList();

    if (kDebugMode) {
      // ignore: avoid_print
      print('Clinics fetched: ${clinicsList.length}');
    }

    return forLabTechnician
        ? filterForLabTechnician(clinicsList)
        : filterForRadiologyTechnologist(clinicsList);
  }

  static bool hasLaboratoryCapability(Map<String, dynamic> clinic) {
    if (clinic['hasLab'] == true) return true;
    if (_services(clinic).any((s) => _labServices.contains(s.toLowerCase()))) return true;
    return _features(clinic).any((f) => _labServices.contains(f.toLowerCase()));
  }

  static bool hasRadiologyCapability(Map<String, dynamic> clinic) {
    if (clinic['hasRadio'] == true) return true;
    if (_services(clinic).any((s) => _radioServices.contains(s.toLowerCase()))) return true;
    return _features(clinic).any((f) => _radioServices.contains(f.toLowerCase()));
  }

  static List<Map<String, dynamic>> filterForLabTechnician(List<Map<String, dynamic>> clinics) {
    return clinics.where(hasLaboratoryCapability).toList()
      ..sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
  }

  static List<Map<String, dynamic>> filterForRadiologyTechnologist(List<Map<String, dynamic>> clinics) {
    return clinics.where(hasRadiologyCapability).toList()
      ..sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
  }

  static List<String> _features(Map<String, dynamic> clinic) {
    final raw = clinic['features'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }

  static List<String> _services(Map<String, dynamic> clinic) {
    final raw = clinic['services'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }
}
