import 'package:shared_preferences/shared_preferences.dart';

class TechnicianSession {
  TechnicianSession._();
  static final instance = TechnicianSession._();

  static const _kUserId = 'technician.userId';
  static const _kOrgId = 'technician.orgId';
  static const _kName = 'technician.name';
  static const _kRole = 'technician.role';

  String userId = '';
  String orgId = '';
  String name = '';
  String role = '';

  bool get isRadiologyRole {
    final r = role.trim();
    return r == 'Radiologist' ||
        r == 'Radiology Technologist' ||
        r == 'Radiology Technician' ||
        r == 'Radiology Tech';
  }

  bool get isLabRole {
    final r = role.trim();
    return r == 'Lab Technician' || r == 'LabTechnician';
  }

  Future<void> save({
    required String userId,
    required String orgId,
    String? name,
    String? role,
  }) async {
    this.userId = userId;
    this.orgId = orgId;
    this.name = name ?? '';
    this.role = role ?? '';
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUserId, userId);
    await p.setString(_kOrgId, orgId);
    await p.setString(_kName, this.name);
    await p.setString(_kRole, this.role);
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    userId = p.getString(_kUserId) ?? '';
    orgId = p.getString(_kOrgId) ?? '';
    name = p.getString(_kName) ?? '';
    role = p.getString(_kRole) ?? '';
  }

  Future<void> clear() async {
    userId = '';
    orgId = '';
    name = '';
    role = '';
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUserId);
    await p.remove(_kOrgId);
    await p.remove(_kName);
    await p.remove(_kRole);
  }
}
