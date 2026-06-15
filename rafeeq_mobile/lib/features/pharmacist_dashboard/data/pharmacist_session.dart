import 'package:shared_preferences/shared_preferences.dart';

/// Persisted pharmacist login session (JWT + identity for API headers).
class PharmacistSession {
  PharmacistSession._();
  static final instance = PharmacistSession._();

  static const _kUserId = 'pharmacist.userId';
  static const _kOrgId = 'pharmacist.orgId';
  static const _kName = 'pharmacist.name';
  static const _kToken = 'pharmacist.token';

  String userId = '';
  String orgId = '';
  String name = '';
  String token = '';

  Future<void> save({
    required String userId,
    required String orgId,
    String? name,
    String? token,
  }) async {
    this.userId = userId;
    this.orgId = orgId;
    this.name = name ?? '';
    this.token = token ?? '';
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUserId, userId);
    await p.setString(_kOrgId, orgId);
    await p.setString(_kName, this.name);
    if (this.token.isNotEmpty) {
      await p.setString(_kToken, this.token);
    } else {
      await p.remove(_kToken);
    }
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    userId = p.getString(_kUserId) ?? '';
    orgId = p.getString(_kOrgId) ?? '';
    name = p.getString(_kName) ?? '';
    token = p.getString(_kToken) ?? '';
  }

  Future<void> clear() async {
    userId = '';
    orgId = '';
    name = '';
    token = '';
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUserId);
    await p.remove(_kOrgId);
    await p.remove(_kName);
    await p.remove(_kToken);
  }
}
