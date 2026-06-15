/// Result from the browser HTML5 Geolocation API (web-only).
class BrowserGeoResult {
  const BrowserGeoResult({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Mobile/desktop stub — browser geolocation is unavailable.
Future<BrowserGeoResult?> captureBrowserGeolocation({
  Duration timeout = const Duration(seconds: 8),
}) async =>
    null;
