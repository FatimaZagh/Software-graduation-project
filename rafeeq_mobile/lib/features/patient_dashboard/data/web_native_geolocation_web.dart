import 'dart:html' as html;

import 'package:flutter/foundation.dart';

/// Result from the browser HTML5 Geolocation API.
class BrowserGeoResult {
  const BrowserGeoResult({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Invokes `navigator.geolocation.getCurrentPosition` via modern `dart:html`.
///
/// Dart 3.11+ exposes [html.Geolocation.getCurrentPosition] as a [Future] with
/// named options — not positional callbacks — so this avoids compile errors.
Future<BrowserGeoResult?> captureBrowserGeolocation({
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    final geolocation = html.window.navigator.geolocation;

    final geoPosition = await geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: timeout,
      maximumAge: Duration.zero,
    );

    final coords = geoPosition.coords;
    if (coords == null) return null;

    final lat = coords.latitude?.toDouble();
    final lng = coords.longitude?.toDouble();

    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
      return null;
    }

    return BrowserGeoResult(latitude: lat, longitude: lng);
  } catch (error) {
    debugPrint('Web location native prompt rejected or closed: $error');
    return null;
  }
}
