import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Backend HTTP origin (Express / Mongo API).
///
/// Override for device / staging:
/// `flutter run --dart-define=RAFEEQ_API_BASE=http://YOUR_LAN_IP:3000`
///
/// Defaults: Web → same host :3000; Android emulator → 10.0.2.2:3000;
/// iOS simulator / desktop → 127.0.0.1:3000. Use dart-define on physical devices.
String resolveRafeeqApiBase() {
  const fromEnv = String.fromEnvironment('RAFEEQ_API_BASE', defaultValue: '');
  final trimmed = fromEnv.trim();
  if (trimmed.isNotEmpty) {
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  if (kIsWeb) {
    final o = Uri.base;
    if (o.host.isEmpty) return 'http://localhost:3000';
    final scheme = o.scheme == 'https' ? 'https' : 'http';
    return '$scheme://${o.host}:3000';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:3000';
    case TargetPlatform.iOS:
      return 'http://127.0.0.1:3000';
    default:
      return 'http://127.0.0.1:3000';
  }
}

/// Use this getter so Flutter Web resolves the API host alongside the tab (localhost vs LAN).
String get rafeeqApiBase => resolveRafeeqApiBase();
