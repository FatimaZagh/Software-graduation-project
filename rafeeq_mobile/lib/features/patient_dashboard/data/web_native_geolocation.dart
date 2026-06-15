// Cross-platform entry for Chrome HTML5 geolocation (`dart:html` on web).
export 'web_native_geolocation_stub.dart'
    if (dart.library.html) 'web_native_geolocation_web.dart';
