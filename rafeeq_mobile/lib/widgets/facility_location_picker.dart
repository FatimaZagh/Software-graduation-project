import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../features/auth/services/nominatim_service.dart';

const Color _gold = Color(0xFFD4AF37);

/// Premium facility location picker: interactive map, fixed center pin, search + confirm.
class FacilityLocationPicker extends StatefulWidget {
  const FacilityLocationPicker({
    super.key,
    required this.mapCenter,
    this.searchCityName = '',
    this.locationConfirmed = false,
    this.confirmedPreview = '',
    this.onLocationConfirmed,
    this.mapHeight = 340,
  });

  final LatLng mapCenter;
  final String searchCityName;
  final bool locationConfirmed;
  final String confirmedPreview;
  final void Function(NominatimReverseResult result)? onLocationConfirmed;
  final double mapHeight;

  @override
  State<FacilityLocationPicker> createState() => _FacilityLocationPickerState();
}

class _FacilityLocationPickerState extends State<FacilityLocationPicker> {
  static const _debounceMs = 300;

  final _mapController = MapController();
  final _nominatim = NominatimService();
  final _layerLink = LayerLink();
  final _searchFocus = FocusNode();
  final _search = TextEditingController();

  Timer? _debounce;
  Timer? _overlayHideTimer;
  OverlayEntry? _overlayEntry;

  bool _searching = false;
  bool _confirming = false;
  List<NominatimPlace> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(widget.mapCenter, 14);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _overlayHideTimer?.cancel();
    _hideSuggestionsOverlay();
    _searchFocus.removeListener(_onFocusChanged);
    _searchFocus.dispose();
    _search.dispose();
    _nominatim.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_searchFocus.hasFocus && _suggestions.isNotEmpty) {
      _overlayHideTimer?.cancel();
      _showSuggestionsOverlay();
    } else if (!_searchFocus.hasFocus) {
      _overlayHideTimer?.cancel();
      _overlayHideTimer = Timer(const Duration(milliseconds: 220), () {
        if (mounted && !_searchFocus.hasFocus) _hideSuggestionsOverlay();
      });
    }
  }

  void _hideSuggestionsOverlay() {
    _overlayHideTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showSuggestionsOverlay() {
    if (_suggestions.isEmpty || !mounted) {
      _hideSuggestionsOverlay();
      return;
    }
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(builder: _buildSuggestionsOverlay);
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  Widget _buildSuggestionsOverlay(BuildContext ctx) {
    final screenWidth = MediaQuery.sizeOf(ctx).width;
    final width = screenWidth > 600 ? 500.0 : (screenWidth - 56);

    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 52),
        child: Material(
          elevation: 14,
          color: const Color(0xFF121816),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1.4),
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final place = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.place_outlined, color: _gold.withValues(alpha: 0.95), size: 22),
                  title: Text(
                    place.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.92), fontSize: 13),
                  ),
                  onTap: () => _selectSuggestion(place),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      _hideSuggestionsOverlay();
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () => _searchLocation(q));
  }

  Future<void> _searchLocation(String query) async {
    try {
      final places = await _nominatim.search(
        query,
        cityName: widget.searchCityName,
        biasCenter: _mapController.camera.center,
        countryCodes: 'ps,sa,ae,jo,eg',
      );
      if (!mounted) return;
      setState(() {
        _suggestions = places;
        _searching = false;
      });
      if (_searchFocus.hasFocus && places.isNotEmpty) {
        _showSuggestionsOverlay();
      } else {
        _hideSuggestionsOverlay();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      _hideSuggestionsOverlay();
    }
  }

  void _selectSuggestion(NominatimPlace place) {
    if (!place.isValid) return;
    final selected = place.latLng;
    _hideSuggestionsOverlay();
    setState(() {
      _suggestions = [];
      _searching = false;
    });
    _search.text = place.shortLabel;
    _searchFocus.unfocus();
    try {
      _mapController.move(selected, 16);
    } catch (_) {}
  }

  LatLng get _mapCenter => _mapController.camera.center;

  Future<void> _confirmLocation() async {
    setState(() => _confirming = true);
    try {
      final center = _mapCenter;
      final details = await _nominatim.reverseGeocodeDetails(center);
      if (!mounted) return;
      if (details == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not resolve this location. Try moving the map slightly.')),
        );
        return;
      }
      widget.onLocationConfirmed?.call(details);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Facility location',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: _gold, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          'Pan the map and align the gold pin, search for a place, then confirm.',
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: widget.mapHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.mapCenter,
                    initialZoom: 14,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rafeeq.mobile',
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0, 0.22, 0.72, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: CompositedTransformTarget(
                    link: _layerLink,
                    child: Material(
                      elevation: 8,
                      shadowColor: _gold.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black.withValues(alpha: 0.82),
                      child: TextField(
                        controller: _search,
                        focusNode: _searchFocus,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                        onChanged: _onSearchChanged,
                        onTap: () {
                          if (_suggestions.isNotEmpty) _showSuggestionsOverlay();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search street, district, landmark…',
                          hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: _gold),
                          suffixIcon: _searching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
                                  ),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _gold.withValues(alpha: 0.75), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _gold, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: _gold,
                          size: 52,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 4)),
                          ],
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _gold.withValues(alpha: 0.45),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _confirming ? null : _confirmLocation,
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: _gold.withValues(alpha: 0.45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: _gold.withValues(alpha: 0.5),
                      ),
                      child: _confirming
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : Text(
                              'Confirm Location',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.locationConfirmed && widget.confirmedPreview.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.confirmedPreview,
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
