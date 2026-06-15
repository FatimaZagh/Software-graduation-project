import 'package:shared_preferences/shared_preferences.dart';

/// Persists clinic (organization) admin identity for API headers.
class OrgAdminSession {
  OrgAdminSession._();
  static final OrgAdminSession instance = OrgAdminSession._();

  static const _kUserId = 'org_admin.userId';
  static const _kOrgId = 'org_admin.orgId';
  static const _kName = 'org_admin.name';
  static const _kClinicId = 'org_admin.clinicId';

  String? userId;
  String? orgId;
  String? displayName;
  String? clinicId;

  bool get isLoggedIn => (userId ?? '').isNotEmpty && (orgId ?? '').isNotEmpty;

  Future<void> save({
    required String userId,
    required String orgId,
    String? name,
    String? clinicId,
  }) async {
    this.userId = userId;
    this.orgId = orgId;
    displayName = name;
    this.clinicId = _normalizeClinicId(clinicId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kOrgId, orgId);
    if (name != null) await prefs.setString(_kName, name);
    if (this.clinicId != null) {
      await prefs.setString(_kClinicId, this.clinicId!);
    } else {
      await prefs.remove(_kClinicId);
    }
  }

  Future<void> setClinicId(String? clinicId) async {
    this.clinicId = _normalizeClinicId(clinicId);
    final prefs = await SharedPreferences.getInstance();
    if (this.clinicId != null) {
      await prefs.setString(_kClinicId, this.clinicId!);
    } else {
      await prefs.remove(_kClinicId);
    }
  }

  static String? _normalizeClinicId(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    final lower = v.toLowerCase();
    if (lower == 'undefined' || lower == 'null') return null;
    return v;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString(_kUserId);
    orgId = prefs.getString(_kOrgId);
    displayName = prefs.getString(_kName);
    clinicId = _normalizeClinicId(prefs.getString(_kClinicId));
  }

  Future<void> clear() async {
    userId = null;
    orgId = null;
    displayName = null;
    clinicId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kOrgId);
    await prefs.remove(_kName);
    await prefs.remove(_kClinicId);
  }
}
