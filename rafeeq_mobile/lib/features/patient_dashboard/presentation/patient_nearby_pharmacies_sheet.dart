import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../data/patient_portal_api.dart';
import '../data/web_native_geolocation.dart';
import 'patient_locale_text.dart';
import 'patient_theme.dart';

/// Central Nablus coordinates — guaranteed safe fallback for web GPS stalls.
const double defaultNablusLat = 32.2211;
const double defaultNablusLng = 35.2603;
final LatLng kNablusFallbackOrigin = LatLng(defaultNablusLat, defaultNablusLng);

bool _isValidCoordinate(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  if (lat.isNaN || lng.isNaN || lat.isInfinite || lng.isInfinite) return false;
  if (lat == 0 && lng == 0) return false;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
  return true;
}

bool _isValidLatLng(LatLng? point) {
  if (point == null) return false;
  return _isValidCoordinate(point.latitude, point.longitude);
}

/// Map + list of external pharmacies stocking a drug (failover search).
Future<String?> showPatientNearbyPharmaciesSheet(
  BuildContext context, {
  required String drugId,
  required String drugName,
  required LatLng searchOrigin,
  String? excludePharmacyId,
  double radiusKm = 10,
  int remainingQty = 1,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kPatientSheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => PatientNearbyPharmaciesSheet(
      drugId: drugId,
      drugName: drugName,
      searchOrigin: searchOrigin,
      excludePharmacyId: excludePharmacyId,
      radiusKm: radiusKm,
      remainingQty: remainingQty,
    ),
  );
}

class PatientNearbyPharmaciesSheet extends StatefulWidget {
  const PatientNearbyPharmaciesSheet({
    super.key,
    required this.drugId,
    required this.drugName,
    required this.searchOrigin,
    this.excludePharmacyId,
    this.radiusKm = 10,
    this.remainingQty = 1,
  });

  final String drugId;
  final String drugName;
  final LatLng searchOrigin;
  final String? excludePharmacyId;
  final double radiusKm;
  final int remainingQty;

  @override
  State<PatientNearbyPharmaciesSheet> createState() => _PatientNearbyPharmaciesSheetState();
}

class _PatientNearbyPharmaciesSheetState extends State<PatientNearbyPharmaciesSheet> {
  static final _highlightColor = Colors.red;

  final _mapController = MapController();
  List<Map<String, dynamic>> _pharmacies = [];
  bool _loading = true;
  String? _error;
  LatLng _userPosition = kNablusFallbackOrigin;
  bool _isLoadingLocation = true;
  bool _isUsingFallback = true;
  int _selectedPharmacyIndex = 0;

  bool get _mapGeometryReady => !_isLoadingLocation;

  LatLng get _safeMapCenter {
    if (_isValidLatLng(_userPosition)) return _userPosition;
    final destination = _selectedPharmacyLatLng;
    if (_isValidLatLng(destination)) return destination!;
    if (_isValidLatLng(widget.searchOrigin)) return widget.searchOrigin;
    return kNablusFallbackOrigin;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await determineUserPosition(fromUserGesture: false);
    if (!mounted) return;
    await _search();
  }

  /// Web: HTML5 `navigator.geolocation` (user-gesture prompt). Mobile: Geolocator sensors.
  Future<void> determineUserPosition({bool fromUserGesture = false}) async {
    if (mounted) setState(() => _isLoadingLocation = true);

    if (kIsWeb) {
      if (!fromUserGesture) {
        await _useNablusFallback();
        return;
      }
      await _determineUserPositionOnWeb(fromUserGesture: fromUserGesture);
      return;
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (_isValidCoordinate(position.latitude, position.longitude)) {
          await _updateLocationState(position.latitude, position.longitude);
          return;
        }
      }
      await _useNablusFallback();
    } catch (e) {
      debugPrint('Mobile GPS core sensor capture failed: $e');
      await _useNablusFallback();
    }
  }

  /// Flutter Web: native `dart:html` navigator.geolocation inside the click gesture stack.
  Future<void> _determineUserPositionOnWeb({required bool fromUserGesture}) async {
    try {
      final result = await captureBrowserGeolocation(
        timeout: fromUserGesture ? const Duration(seconds: 8) : const Duration(seconds: 3),
      );

      if (result != null && _isValidCoordinate(result.latitude, result.longitude)) {
        await _updateLocationState(result.latitude, result.longitude);
        return;
      }
    } catch (e) {
      debugPrint('Native HTML5 Geolocation failed: $e');
    }

    await _useNablusFallback();
  }

  Future<void> _updateLocationState(double lat, double lng) async {
    if (!mounted) return;
    setState(() {
      _userPosition = LatLng(lat, lng);
      _isLoadingLocation = false;
      _isUsingFallback = false;
    });
    _focusCameraOnUser(_userPosition, zoom: 14.5);
  }

  Future<void> _useNablusFallback() async {
    if (!mounted) return;
    setState(() {
      _userPosition = kNablusFallbackOrigin;
      _isLoadingLocation = false;
      _isUsingFallback = true;
    });
    _focusCameraOnUser(_userPosition, zoom: 14.0);
  }

  /// Equivalent to `CameraUpdate.newLatLngZoom` for flutter_map.
  void _focusCameraOnUser(LatLng location, {double zoom = 14.5}) {
    if (!_isValidLatLng(location)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(location, zoom);
      } catch (error) {
        debugPrint('[NearbyPharmacies] focus camera error: $error');
        _safeMoveMap(location, zoom);
      }
    });
  }

  LatLng? _pharmacyLatLng(Map<String, dynamic> ph) {
    final lat = ph['latitude'];
    final lng = ph['longitude'];
    if (lat == null || lng == null) return null;
    final point = LatLng((lat as num).toDouble(), (lng as num).toDouble());
    return _isValidLatLng(point) ? point : null;
  }

  LatLng? get _selectedPharmacyLatLng {
    if (_pharmacies.isEmpty) return null;
    final index = _selectedPharmacyIndex.clamp(0, _pharmacies.length - 1);
    return _pharmacyLatLng(_pharmacies[index]);
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final origin = _isValidLatLng(_userPosition) ? _userPosition : kNablusFallbackOrigin;

    try {
      final data = await PatientPortalApi.searchPharmaciesByDrug(
        drugId: widget.drugId,
        lat: origin.latitude,
        lng: origin.longitude,
        radiusKm: widget.radiusKm,
        excludePharmacyId: widget.excludePharmacyId,
      );
      final list = data['pharmacies'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _pharmacies = [for (final e in list) if (e is Map) Map<String, dynamic>.from(e)];
        _selectedPharmacyIndex = 0;
        _loading = false;
      });
      if (_mapGeometryReady) _fitMapToViewport();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _selectPharmacy(int index) {
    if (index == _selectedPharmacyIndex) {
      _fitMapToViewport();
      return;
    }
    setState(() => _selectedPharmacyIndex = index);
    _fitMapToViewport();
  }

  Future<void> _onEnableLocationPressed() async {
    await determineUserPosition(fromUserGesture: true);
    if (!mounted) return;
    await _search();
    if (!mounted) return;
    if (!_isUsingFallback) {
      _focusCameraOnUser(_userPosition, zoom: 14.5);
    }
  }

  List<LatLng> _collectValidViewportPoints() {
    final points = <LatLng>[];
    if (_isValidLatLng(_userPosition)) points.add(_userPosition);

    final destination = _selectedPharmacyLatLng;
    if (_isValidLatLng(destination)) points.add(destination!);

    for (final ph in _pharmacies) {
      final point = _pharmacyLatLng(ph);
      if (point != null) points.add(point);
    }

    return points;
  }

  bool _pointsAreCoincident(List<LatLng> points) {
    if (points.length < 2) return true;
    final first = points.first;
    return points.every(
      (p) =>
          (p.latitude - first.latitude).abs() < 1e-9 &&
          (p.longitude - first.longitude).abs() < 1e-9,
    );
  }

  void _fitMapToViewport() {
    if (!_mapGeometryReady) return;

    final points = _collectValidViewportPoints();
    if (points.isEmpty) {
      _safeMoveMap(_safeMapCenter, 13);
      return;
    }

    if (points.length == 1 || _pointsAreCoincident(points)) {
      _safeMoveMap(points.first, 14);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapGeometryReady) return;
      try {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
        );
      } catch (error) {
        debugPrint('[NearbyPharmacies] fitCamera error: $error');
        _safeMoveMap(_safeMapCenter, 13);
      }
    });
  }

  void _safeMoveMap(LatLng center, double zoom) {
    if (!_isValidLatLng(center)) {
      center = kNablusFallbackOrigin;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(center, zoom);
      } catch (error) {
        debugPrint('[NearbyPharmacies] move map error: $error');
      }
    });
  }

  List<Marker> _buildMarkers() {
    if (!_mapGeometryReady) return const [];

    final markers = <Marker>[
      Marker(
        point: _isValidLatLng(_userPosition) ? _userPosition : kNablusFallbackOrigin,
        width: 46,
        height: 46,
        child: Container(
          decoration: BoxDecoration(
            color: !_isUsingFallback ? _highlightColor : kPatientGold.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: (!_isUsingFallback ? _highlightColor : kPatientGold).withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            !_isUsingFallback ? Icons.person_pin : Icons.location_city,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    ];

    for (var i = 0; i < _pharmacies.length; i++) {
      final point = _pharmacyLatLng(_pharmacies[i]);
      if (point == null) continue;
      final isSelected = i == _selectedPharmacyIndex;
      markers.add(
        Marker(
          point: point,
          width: isSelected ? 44 : 40,
          height: isSelected ? 44 : 40,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? _highlightColor : Colors.orangeAccent.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : kPatientGold,
                width: isSelected ? 2.5 : 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _highlightColor.withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.local_pharmacy,
              color: Colors.white,
              size: isSelected ? 22 : 20,
            ),
          ),
        ),
      );
    }
    return markers;
  }

  Widget _mapLoadingPlaceholder() {
    return Container(
      color: kPatientFieldFill,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: kPatientGold),
      ),
    );
  }

  Widget _buildMapCanvas(bool isArabic) {
    if (!_mapGeometryReady) {
      return _mapLoadingPlaceholder();
    }

    final markers = _buildMarkers();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _safeMapCenter,
            initialZoom: 13,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            onMapReady: _fitMapToViewport,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rafeeq.mobile',
            ),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
        if (_isUsingFallback)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _onEnableLocationPressed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPatientGold.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.my_location, color: kPatientGold, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isArabic ? 'تفعيل موقعي الحالي' : 'Enable my live location',
                        style: patientBodyStyle(color: kPatientGoldLight, size: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _pharmacyTile(Map<String, dynamic> ph, {required bool isArabic, required int index}) {
    final name = patientLocaleSegment(ph['name']?.toString() ?? 'Pharmacy', isArabic: isArabic);
    final dist = ph['distanceKm'];
    final stock = ph['stockQuantity'];
    final inStock = ph['inStock'] == true;
    final pharmacyId = ph['pharmacyId']?.toString() ?? '';
    final addressRaw = ph['address']?.toString() ?? '';
    final addressLine =
        addressRaw.isNotEmpty ? patientLocaleSegment(addressRaw, isArabic: isArabic) : '';
    final isSelected = index == _selectedPharmacyIndex;

    return GestureDetector(
      onTap: () => _selectPharmacy(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kPatientFieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _highlightColor.withValues(alpha: 0.85) : kPatientGold.withValues(alpha: 0.28),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name, style: patientBodyStyle().copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _highlightColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isArabic ? 'المسار' : 'Route',
                      style: patientBodyStyle(color: _highlightColor, size: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (dist != null)
              Text(
                isArabic ? '$dist كم' : '$dist km away',
                style: patientBodyStyle(color: kPatientGoldLight, size: 13),
              ),
            const SizedBox(height: 4),
            Text(
              inStock
                  ? (isArabic ? 'متوفر — $stock وحدة' : 'Available — $stock units')
                  : (isArabic ? 'غير متوفر' : 'Out of stock'),
              style: patientBodyStyle(
                color: inStock ? const Color(0xFF4CAF50) : Colors.redAccent,
                size: 13,
              ),
            ),
            if (addressLine.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(addressLine, style: patientBodyStyle(color: Colors.white54, size: 12)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: pharmacyId.isEmpty || !inStock ? null : () => Navigator.pop(context, pharmacyId),
                style: FilledButton.styleFrom(
                  backgroundColor: kPatientGoldDeep,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isArabic ? 'اطلب من هنا' : 'Request Here',
                  style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = patientIsArabic(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'الصيدليات المجاورة' : 'Nearby Pharmacies',
              style: patientTitleStyle(18),
            ),
            Text(
              widget.drugName,
              style: GoogleFonts.urbanist(color: kPatientGold.withValues(alpha: 0.85), fontSize: 13),
            ),
            if (widget.remainingQty > 1)
              Text(
                isArabic
                    ? 'البحث عن ${widget.remainingQty} وحدة متبقية'
                    : 'Searching for ${widget.remainingQty} remaining units',
                style: patientBodyStyle(color: kPatientGoldLight, size: 12),
              ),
            Text(
              !_isUsingFallback
                  ? (isArabic
                      ? 'موقعك الحالي · ضمن ${widget.radiusKm.toStringAsFixed(0)} كم'
                      : 'Your live location · within ${widget.radiusKm.toStringAsFixed(0)} km')
                  : (isArabic
                      ? 'وسط نابلس (احتياطي) · ضمن ${widget.radiusKm.toStringAsFixed(0)} كم'
                      : 'Central Nablus (fallback) · within ${widget.radiusKm.toStringAsFixed(0)} km'),
              style: patientBodyStyle(color: Colors.white54, size: 12),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 200,
                child: _buildMapCanvas(isArabic),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator(color: kPatientGold)),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: patientBodyStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _search,
                        child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_pharmacies.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_off_outlined, size: 48, color: kPatientGold.withValues(alpha: 0.6)),
                        const SizedBox(height: 12),
                        Text(
                          isArabic ? 'لم يتم العثور على صيدليات قريبة' : 'No pharmacies found nearby',
                          style: patientTitleStyle(16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isArabic
                              ? 'لم نجد صيدليات مجاورة تحتوي على هذا الدواء ضمن نطاق ${widget.radiusKm.toStringAsFixed(0)} كم. '
                                  'حاول لاحقاً أو تواصل مع عيادتك.'
                              : 'No nearby pharmacies stock this medication within ${widget.radiusKm.toStringAsFixed(0)} km. '
                                  'Try again later or contact your clinic.',
                          style: patientBodyStyle(color: Colors.white54, size: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  color: kPatientGold,
                  onRefresh: () async {
                    await determineUserPosition(fromUserGesture: true);
                    await _search();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Text(
                        isArabic
                            ? 'تم العثور على ${_pharmacies.length} صيدلية'
                            : '${_pharmacies.length} pharmacy(ies) found',
                        style: patientBodyStyle(color: Colors.white70, size: 13),
                      ),
                      const SizedBox(height: 8),
                      ..._pharmacies.asMap().entries.map(
                            (entry) => _pharmacyTile(entry.value, isArabic: isArabic, index: entry.key),
                          ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
