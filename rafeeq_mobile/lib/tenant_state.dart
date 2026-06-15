import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TenantModules {
  final bool pharmacy;
  final bool labRadiology;
  final bool internsTrainees;
  final bool emergency;

  const TenantModules({
    required this.pharmacy,
    required this.labRadiology,
    required this.internsTrainees,
    required this.emergency,
  });

  factory TenantModules.fromJson(dynamic json) {
    if (json is! Map) {
      return const TenantModules(pharmacy: false, labRadiology: false, internsTrainees: false, emergency: false);
    }
    bool b(String k) => json[k] == true;
    return TenantModules(
      pharmacy: b('pharmacy'),
      labRadiology: b('labRadiology'),
      internsTrainees: b('internsTrainees'),
      emergency: b('emergency'),
    );
  }
}

class TenantTheme {
  final String primaryColor;
  final String accentColor;
  final String logoUrl;
  final String name;

  const TenantTheme({
    required this.primaryColor,
    required this.accentColor,
    required this.logoUrl,
    required this.name,
  });

  factory TenantTheme.fromJson(dynamic json) {
    if (json is! Map) {
      return const TenantTheme(primaryColor: '#004D40', accentColor: '#D4AF37', logoUrl: '', name: 'Rafeeq');
    }
    final theme = json['theme'] is Map ? json['theme'] as Map : const {};
    return TenantTheme(
      primaryColor: (theme['primaryColor'] ?? '#004D40').toString(),
      accentColor: (theme['accentColor'] ?? '#D4AF37').toString(),
      logoUrl: (json['logoUrl'] ?? '').toString(),
      name: (json['name'] ?? 'Rafeeq').toString(),
    );
  }
}

class TenantState extends ChangeNotifier {
  static final TenantState instance = TenantState._();
  TenantState._();

  String orgId = '';
  /// Preferred branch after choosing a facility on the landing page (booking / doctor flows).
  String preferredClinicId = '';
  TenantModules modules = const TenantModules(pharmacy: true, labRadiology: true, internsTrainees: true, emergency: true);
  TenantTheme theme = const TenantTheme(primaryColor: '#004D40', accentColor: '#D4AF37', logoUrl: '', name: 'Rafeeq');

  void clear() {
    orgId = '';
    preferredClinicId = '';
    modules = const TenantModules(pharmacy: true, labRadiology: true, internsTrainees: true, emergency: true);
    theme = const TenantTheme(primaryColor: '#004D40', accentColor: '#D4AF37', logoUrl: '', name: 'Rafeeq');
    notifyListeners();
  }

  Future<void> loadFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString('tenant.orgId') ?? '';
    preferredClinicId = p.getString('tenant.preferredClinicId') ?? '';
    if (id.isEmpty) return;
    orgId = id;
    notifyListeners();
  }

  Future<void> persistOrgId() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tenant.orgId', orgId);
  }

  Future<void> setPreferredClinicId(String? clinicId) async {
    preferredClinicId = (clinicId ?? '').trim();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    if (preferredClinicId.isEmpty) {
      await p.remove('tenant.preferredClinicId');
    } else {
      await p.setString('tenant.preferredClinicId', preferredClinicId);
    }
  }

  void setFromOrgPayload(String orgIdValue, dynamic payload) {
    orgId = orgIdValue;
    modules = TenantModules.fromJson(payload is Map ? payload['activeModules'] : null);
    theme = TenantTheme.fromJson(payload);
    notifyListeners();
    persistOrgId();
  }
}

Color parseHexColor(String hex, {Color fallback = const Color(0xFF004D40)}) {
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return fallback;
  return Color(v);
}

