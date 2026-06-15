import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../services/nominatim_service.dart';

const Color _gold = Color(0xFFD4AF37);
const Color _goldLight = Color(0xFFFFE8A3);

/// Interactive OSM map: bilingual autocomplete overlay, marker, location preview.
class PharmacyLocationPicker extends StatefulWidget {
  const PharmacyLocationPicker({
    super.key,
    required this.marker,
    required this.locationConfirmed,
    required this.mapCenter,
    required this.searchCityName,
    required this.onMarkerChanged,
    required this.onLocationConfirmed,
    this.searchController,
    this.compact = false,
    this.settingsOverlay = false,
    this.mapHeight = 280,
  });

  final LatLng? marker;
  final bool locationConfirmed;
  final LatLng mapCenter;
  final String searchCityName;
  final void Function(LatLng point, String locationLabel) onMarkerChanged;
  final VoidCallback onLocationConfirmed;
  final TextEditingController? searchController;

  /// Map + drag pin only (no search).
  final bool compact;

  /// Settings: search bar overlaid on map + autocomplete (no confirm button).
  final bool settingsOverlay;
  final double mapHeight;

  @override
  State<PharmacyLocationPicker> createState() => _PharmacyLocationPickerState();
}

class _PharmacyLocationPickerState extends State<PharmacyLocationPicker> {
  static const _debounceMs = 300;

  final _mapController = MapController();
  final _nominatim = NominatimService();
  final _layerLink = LayerLink();
  final _searchFocus = FocusNode();

  late final TextEditingController _search =
      widget.searchController ?? TextEditingController();

  Timer? _debounce;
  Timer? _overlayHideTimer;
  OverlayEntry? _overlayEntry;

  bool _searching = false;
  bool _resolvingLabel = false;
  List<NominatimPlace> _suggestions = [];
  LatLng? _selectedLocation;
  String _locationPreview = '';

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(PharmacyLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapCenter != widget.mapCenter) {
      _mapController.move(widget.mapCenter, 14);
      if (mounted) setState(() => _locationPreview = '');
    }
    if (oldWidget.marker != widget.marker && widget.marker != null) {
      _selectedLocation = widget.marker;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _mapController.move(widget.marker!, 14);
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _overlayHideTimer?.cancel();
    _hideSuggestionsOverlay();
    _searchFocus.removeListener(_onFocusChanged);
    _searchFocus.dispose();
    if (widget.searchController == null) _search.dispose();
    _nominatim.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_searchFocus.hasFocus && _suggestions.isNotEmpty) {
      _overlayHideTimer?.cancel();
      _showSuggestionsOverlay();
    } else if (!_searchFocus.hasFocus) {
      // Defer hide so overlay ListTile taps complete before removal.
      _overlayHideTimer?.cancel();
      _overlayHideTimer = Timer(const Duration(milliseconds: 220), () {
        if (mounted && !_searchFocus.hasFocus) {
          _hideSuggestionsOverlay();
        }
      });
    }
  }

  void _hideSuggestionsOverlay() {
    _overlayHideTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static const double _suggestionsMaxHeight = 250;

  void _showSuggestionsOverlay() {
    if (_suggestions.isEmpty || !mounted) {
      _hideSuggestionsOverlay();
      return;
    }

    if (_overlayEntry == null) {
      final overlay = Overlay.of(context);
      _overlayEntry = OverlayEntry(builder: _buildSuggestionsOverlay);
      overlay.insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  Widget _buildSuggestionsOverlay(BuildContext ctx) {
    final screenWidth = MediaQuery.sizeOf(ctx).width;
    final width = screenWidth > 600 ? 500.0 : (screenWidth - 40);
    final count = _suggestions.length;

    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 56),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _overlayHideTimer?.cancel(),
          child: Material(
            elevation: 12,
            color: const Color(0xFF141A17),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SizedBox(
                height: _suggestionsMaxHeight,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: count,
                  physics: count > 4
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final place = _suggestions[index];
                    return _suggestionTile(place);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _suggestionTile(NominatimPlace place) {
    return Material(
      color: Colors.black,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Icon(Icons.place_outlined, color: _gold.withValues(alpha: 0.95), size: 22),
        title: Text(
          place.displayName,
          textAlign: TextAlign.start,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.urbanist(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        hoverColor: _gold.withValues(alpha: 0.08),
        splashColor: _gold.withValues(alpha: 0.15),
        onTap: () => _selectSuggestion(place),
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
        biasCenter: widget.mapCenter,
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

  void _applyLocation(LatLng point, String label) {
    setState(() {
      _selectedLocation = point;
      _locationPreview = label;
    });
    widget.onMarkerChanged(point, label);
  }

  void _selectSuggestion(NominatimPlace place) {
    if (!place.isValid) return;
    final lat = place.latitude;
    final lon = place.longitude;

    final displayName = place.displayName;
    final selected = LatLng(lat, lon);

    _overlayHideTimer?.cancel();
    _hideSuggestionsOverlay();

    setState(() {
      _selectedLocation = selected;
      _locationPreview = displayName;
      _suggestions = [];
      _searching = false;
    });

    _search.text = displayName;
    _search.selection = TextSelection.collapsed(offset: displayName.length);
    _searchFocus.unfocus();

    widget.onMarkerChanged(selected, displayName);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(selected, 16.5);
      } catch (_) {
        // Map may not be ready on first frame; retry once.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _mapController.move(selected, 16.5);
            } catch (_) {}
          }
        });
      }
    });
  }

  Future<void> _resolveLabelForPoint(LatLng point) async {
    setState(() => _resolvingLabel = true);
    try {
      final label = await _nominatim.reverseGeocode(point);
      if (!mounted) return;
      final resolved = (label != null && label.trim().isNotEmpty)
          ? label.trim()
          : 'Lat ${point.latitude.toStringAsFixed(5)}, Lng ${point.longitude.toStringAsFixed(5)}';
      _applyLocation(point, resolved);
    } finally {
      if (mounted) setState(() => _resolvingLabel = false);
    }
  }

  void _onMapTap(LatLng point) {
    _hideSuggestionsOverlay();
    widget.onMarkerChanged(point, _locationPreview);
    _resolveLabelForPoint(point);
  }

  void _onDragEnd(DragEndDetails details, LatLng point) {
    widget.onMarkerChanged(point, _locationPreview);
    _resolveLabelForPoint(point);
  }

  Widget _selectedLocationPreviewRow() {
    if (_locationPreview.isEmpty && !_resolvingLabel) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161A18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_resolvingLabel)
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Icon(Icons.location_on_outlined, color: _gold.withValues(alpha: 0.9), size: 18),
            ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.urbanist(color: Colors.grey.shade400, fontSize: 12, height: 1.45),
                children: [
                  TextSpan(
                    text: 'Selected Location Preview: ',
                    style: TextStyle(
                      color: _goldLight.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: _resolvingLabel
                        ? 'Resolving address…'
                        : _locationPreview,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlutterMap(LatLng? marker) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: marker ?? widget.mapCenter,
        initialZoom: 14,
        onTap: (_, point) => _onMapTap(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rafeeq.mobile',
        ),
        if (marker != null)
          DragMarkers(
            markers: [
              DragMarker(
                point: marker,
                size: const Size(48, 48),
                builder: (context, pos, isDragging) => AnimatedScale(
                  scale: isDragging ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.location_on,
                    color: _gold,
                    size: 44,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
                onDragEnd: _onDragEnd,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMap(LatLng? marker, {bool expand = false}) {
    final map = _buildFlutterMap(marker);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: expand ? map : SizedBox(height: widget.mapHeight, child: map),
    );
  }

  Widget _buildSearchField() {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _search,
        focusNode: _searchFocus,
        style: const TextStyle(color: Colors.white),
        onChanged: _onSearchChanged,
        onTap: () {
          if (_suggestions.isNotEmpty) _showSuggestionsOverlay();
        },
        decoration: InputDecoration(
          hintText: 'Search places — Rafidia, Nablus, شارع…',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: _gold),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
                  ),
                )
              : _search.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                      onPressed: () {
                        _search.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
          filled: true,
          fillColor: const Color(0xFF161A18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: _gold, width: 1.4),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marker = widget.marker ?? _selectedLocation;

    if (widget.compact) {
      return _buildMap(marker);
    }

    if (widget.settingsOverlay) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMap(marker, expand: true),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                elevation: 6,
                shadowColor: _gold.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF161A18).withValues(alpha: 0.94),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: _buildSearchField(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchField(),
        const SizedBox(height: 10),
        _buildMap(marker),
        _selectedLocationPreviewRow(),
        if (widget.locationConfirmed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade400, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Location confirmed',
                  style: GoogleFonts.urbanist(color: Colors.green.shade300, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: marker == null ? null : widget.onLocationConfirmed,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.grey.shade800,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.pin_drop_outlined),
            label: Text(
              'Confirm Location',
              style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
