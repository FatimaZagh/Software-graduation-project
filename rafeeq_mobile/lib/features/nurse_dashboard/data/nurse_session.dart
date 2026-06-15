import 'package:shared_preferences/shared_preferences.dart';

class NurseSession {
  NurseSession._();
  static final instance = NurseSession._();

  static const _kUserId = 'nurse.userId';
  static const _kOrgId = 'nurse.orgId';
  static const _kName = 'nurse.name';

  String userId = '';
  String orgId = '';
  String name = '';

  Future<void> save({required String userId, required String orgId, String? name}) async {
    this.userId = userId;
    this.orgId = orgId;
    this.name = name ?? '';
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUserId, userId);
    await p.setString(_kOrgId, orgId);
    await p.setString(_kName, this.name);
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    userId = p.getString(_kUserId) ?? '';
    orgId = p.getString(_kOrgId) ?? '';
    name = p.getString(_kName) ?? '';
  }

  Future<void> clear() async {
    userId = '';
    orgId = '';
    name = '';
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUserId);
    await p.remove(_kOrgId);
    await p.remove(_kName);
  }
}
