/// In-memory JWT for the hardcoded platform Super Admin (not a MongoDB user).
class PlatformSuperAdminSession {
  PlatformSuperAdminSession._();

  static String? _token;

  static String? get token => _token;

  static void setToken(String? value) {
    final t = (value ?? '').trim();
    _token = t.isEmpty ? null : t;
  }

  static void clear() {
    _token = null;
  }

  static bool get hasToken => _token != null && _token!.isNotEmpty;
}
