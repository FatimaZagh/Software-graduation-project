import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OpenStreetMap Nominatim geocoding (respect usage policy: low rate, identify app).
class NominatimService {
  NominatimService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://nominatim.openstreetmap.org';
  static const _userAgent = 'RafeeqMobile/1.0 (pharmacy-signup; contact@rafeeq.app)';
  static const _headers = {
    'User-Agent': _userAgent,
    'Accept': 'application/json',
    'Accept-Language': 'ar,en',
  };

  Future<List<NominatimPlace>> search(
    String query, {
    String countryCodes = 'ps',
    String cityName = 'Nablus',
    LatLng? biasCenter,
  }) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final params = <String, String>{
      'q': '$q, $cityName',
      'format': 'json',
      'limit': '10',
      'countrycodes': countryCodes,
      'accept-language': 'ar,en',
      'dedupe': '0',
    };

    if (biasCenter != null) {
      const delta = 0.15;
      final left = biasCenter.longitude - delta;
      final right = biasCenter.longitude + delta;
      final top = biasCenter.latitude + delta;
      final bottom = biasCenter.latitude - delta;
      params['viewbox'] = '$left,$top,$right,$bottom';
      params['bounded'] = '1';
    }

    final uri = Uri.parse('$_base/search').replace(queryParameters: params);

    final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) return [];
    final raw = jsonDecode(res.body);
    if (raw is! List) return [];

    final seen = <String>{};
    final results = <NominatimPlace>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final place = NominatimPlace.fromJson(item);
      if (!place.isValid) continue;
      final key = place.displayName.toLowerCase();
      if (seen.add(key)) results.add(place);
      if (results.length >= 10) break;
    }
    return results;
  }

  Future<String?> reverseGeocode(LatLng point) async {
    final details = await reverseGeocodeDetails(point);
    return details?.displayName;
  }

  Future<NominatimReverseResult?> reverseGeocodeDetails(LatLng point) async {
    final uri = Uri.parse('$_base/reverse').replace(
      queryParameters: {
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'format': 'json',
        'accept-language': 'ar,en',
        'addressdetails': '1',
      },
    );

    final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) return null;

    final address = data['address'];
    String city = '';
    String streetLine = '';
    if (address is Map) {
      city = _firstNonEmpty(address, const [
        'city',
        'town',
        'village',
        'municipality',
        'county',
        'state',
      ]);
      final road = _firstNonEmpty(address, const ['road', 'pedestrian', 'neighbourhood', 'suburb']);
      final house = address['house_number']?.toString() ?? '';
      streetLine = [house, road].where((s) => s.trim().isNotEmpty).join(' ').trim();
    }

    return NominatimReverseResult(
      displayName: data['display_name']?.toString() ?? '',
      city: city,
      streetLine: streetLine,
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  static String _firstNonEmpty(Map address, List<String> keys) {
    for (final key in keys) {
      final v = address[key]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  void dispose() => _client.close();
}

class NominatimReverseResult {
  const NominatimReverseResult({
    required this.displayName,
    required this.city,
    required this.streetLine,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final String city;
  final String streetLine;
  final double latitude;
  final double longitude;

  String get formattedAddress {
    if (streetLine.isNotEmpty) return streetLine;
    if (displayName.isNotEmpty) return displayName.split(',').first.trim();
    return 'Lat ${latitude.toStringAsFixed(5)}, Lng ${longitude.toStringAsFixed(5)}';
  }

  String get googleMapsUrl =>
      'https://www.google.com/maps?q=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
}

class NominatimPlace {
  const NominatimPlace({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);

  bool get isValid => latitude != 0 && longitude != 0;

  String get shortLabel {
    final parts = displayName.split(',');
    return parts.isNotEmpty ? parts.first.trim() : displayName;
  }

  factory NominatimPlace.fromJson(Map<String, dynamic> json) {
    return NominatimPlace(
      displayName: json['display_name']?.toString() ?? 'Unknown',
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(json['lon']?.toString() ?? '') ?? 0,
    );
  }
}
