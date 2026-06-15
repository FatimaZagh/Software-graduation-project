import 'package:shared_preferences/shared_preferences.dart';

/// Persisted doctor login session (JWT for Authorization header).
class DoctorSession {
  DoctorSession._();
  static final instance = DoctorSession._();

  static const _kToken = 'doctor.token';

  String token = '';

  Future<void> save({String? token}) async {
    this.token = token?.trim() ?? '';
    final p = await SharedPreferences.getInstance();
    if (this.token.isNotEmpty) {
      await p.setString(_kToken, this.token);
    } else {
      await p.remove(_kToken);
    }
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_kToken) ?? '';
  }

  Future<void> clear() async {
    token = '';
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
  }
}
