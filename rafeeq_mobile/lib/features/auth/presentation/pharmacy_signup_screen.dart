import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../api_config.dart';
import '../../../widgets/rafeeq_back_home_button.dart';
import '../../../tenant_state.dart';
import '../data/pharmacy_cities.dart';
import '../../pharmacist_dashboard/presentation/pharmacist_profile_photo_picker.dart';
import '../widgets/pharmacy_location_picker.dart';
import 'auth_signup_theme.dart';

const _weekDays = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

/// Production route: POST /api/pharmacies
const _kExternalPharmacyRegisterPath = '/api/pharmacies';

/// Premium dark pharmacy registration with map-based location picker.
class PharmacySignupScreen extends StatefulWidget {
  const PharmacySignupScreen({super.key, this.presetOrgId, this.presetOrgName});

  final String? presetOrgId;
  final String? presetOrgName;

  @override
  State<PharmacySignupScreen> createState() => _PharmacySignupScreenState();
}

class _PharmacySignupScreenState extends State<PharmacySignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _mapSearch = TextEditingController();

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  final _pharmacyName = TextEditingController();
  final _licenseNumber = TextEditingController();

  String _city = kPharmacyCities.first.name;
  bool _is24Hours = false;
  String _licenseImageLabel = '';

  final Set<String> _openDays = {};
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  LatLng? _marker;
  String _locationPreviewLabel = '';
  bool _locationConfirmed = false;
  String _profileImageBase64 = '';

  String? _orgId;
  String _orgName = '';
  String? _suggestedOrgId;
  String _suggestedOrgName = '';
  List<dynamic> _orgs = [];
  bool _submitting = false;
  /// `External` = independent community pharmacy (no facility). `Internal` = clinic-linked.
  String _pharmacyType = 'External';

  bool get _isInternalPharmacy => _pharmacyType == 'Internal';

  LatLng get _mapCenter => pharmacyCityByName(_city).center;

  @override
  void initState() {
    super.initState();
    // Independent (External) is the default — facility link is optional.
    if (widget.presetOrgId?.trim().isNotEmpty == true) {
      _suggestedOrgId = widget.presetOrgId!.trim();
      _suggestedOrgName = widget.presetOrgName ?? '';
    }
    _loadOrgs();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _mapSearch.dispose();
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _pharmacyName.dispose();
    _licenseNumber.dispose();
    super.dispose();
  }

  Future<void> _loadOrgs() async {
    try {
      final r = await http
          .get(Uri.parse('$rafeeqApiBase/api/organizations?includePending=true'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200 && mounted) {
        setState(() {
          _orgs = jsonDecode(r.body) as List<dynamic>;
          if (_isInternalPharmacy &&
              (_orgId == null || _orgId!.isEmpty) &&
              TenantState.instance.orgId.isNotEmpty) {
            _orgId = TenantState.instance.orgId;
            final match = _orgs.cast<Map>().where((o) => o['_id']?.toString() == _orgId);
            if (match.isNotEmpty) _orgName = match.first['name']?.toString() ?? _orgName;
          }
          if (_isInternalPharmacy &&
              (_orgId == null || _orgId!.isEmpty) &&
              _suggestedOrgId != null &&
              _suggestedOrgId!.isNotEmpty) {
            _orgId = _suggestedOrgId;
            _orgName = _suggestedOrgName;
          }
        });
      }
    } catch (_) {}
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _operatingHoursPayload() {
    if (_is24Hours) return '24 Hours';
    final days = _weekDays.where(_openDays.contains).join(', ');
    if (days.isEmpty || _openTime == null || _closeTime == null) return '';
    return '$days · ${_formatTime(_openTime!)} - ${_formatTime(_closeTime!)}';
  }

  void _onCityChanged(String? value) {
    if (value == null || value == _city) return;
    final center = pharmacyCityByName(value).center;
    setState(() {
      _city = value;
      _marker = center;
      _locationPreviewLabel = '';
      _locationConfirmed = false;
    });
  }

  void _onMarkerChanged(LatLng point, String locationLabel) {
    setState(() {
      _marker = point;
      _locationPreviewLabel = locationLabel;
      _locationConfirmed = false;
    });
  }

  void _confirmLocation() {
    if (_marker == null) return;
    setState(() => _locationConfirmed = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coordinates saved', style: GoogleFonts.urbanist()),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  Future<void> _pickTime({required bool isOpen}) async {
    final initial = isOpen
        ? (_openTime ?? const TimeOfDay(hour: 8, minute: 0))
        : (_closeTime ?? const TimeOfDay(hour: 23, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AuthSignupColors.gold,
              onPrimary: Colors.black,
              surface: Color(0xFF1A2220),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isOpen) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  String? _validateOperatingHours() {
    if (_is24Hours) return null;
    if (_openDays.isEmpty) return 'Select at least one open day';
    if (_openTime == null || _closeTime == null) return 'Set open and close times';
    final openMins = _openTime!.hour * 60 + _openTime!.minute;
    final closeMins = _closeTime!.hour * 60 + _closeTime!.minute;
    if (closeMins <= openMins) return 'Close time must be after open time';
    return null;
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      color: AuthSignupColors.glassCard,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AuthSignupColors.gold.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AuthSignupTheme.sectionTitleStyle()),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _operatingHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: _is24Hours,
          onChanged: (v) => setState(() {
            _is24Hours = v ?? false;
            if (_is24Hours) {
              _openDays.clear();
              _openTime = null;
              _closeTime = null;
            }
          }),
          activeColor: AuthSignupColors.gold,
          checkColor: Colors.black,
          title: Text('Open 24 hours?', style: GoogleFonts.urbanist(color: Colors.white)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (!_is24Hours) ...[
          const SizedBox(height: 8),
          Text(
            'Open days',
            style: GoogleFonts.urbanist(color: Colors.grey.shade400, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final day in _weekDays)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(day),
                      selected: _openDays.contains(day),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _openDays.add(day);
                          } else {
                            _openDays.remove(day);
                          }
                        });
                      },
                      selectedColor: AuthSignupColors.gold.withValues(alpha: 0.35),
                      checkmarkColor: Colors.black,
                      labelStyle: TextStyle(
                        color: _openDays.contains(day) ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: const Color(0xFF1A1F1C),
                      side: BorderSide(color: AuthSignupColors.gold.withValues(alpha: 0.45)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(isOpen: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AuthSignupColors.goldLight,
                    side: BorderSide(color: AuthSignupColors.gold.withValues(alpha: 0.65)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.wb_sunny_outlined, color: AuthSignupColors.gold, size: 20),
                  label: Text(
                    _openTime == null ? 'Open time' : 'Open · ${_formatTime(_openTime!)}',
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(isOpen: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AuthSignupColors.goldLight,
                    side: BorderSide(color: AuthSignupColors.gold.withValues(alpha: 0.65)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.nightlight_round, color: AuthSignupColors.gold, size: 20),
                  label: Text(
                    _closeTime == null ? 'Close time' : 'Close · ${_formatTime(_closeTime!)}',
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          if (_operatingHoursPayload().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _operatingHoursPayload(),
              style: GoogleFonts.urbanist(color: AuthSignupColors.goldLight, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _pickProfilePhoto() async {
    final img = await pickPharmacistProfilePhoto();
    if (img != null && mounted) setState(() => _profileImageBase64 = img);
  }

  /// External pharmacy + pharmacist — POST /api/pharmacies
  Map<String, dynamic> _buildExternalPharmacyPayload() {
    return {
      'name': _pharmacyName.text.trim(),
      'latitude': _marker!.latitude,
      'longitude': _marker!.longitude,
      'status': 'Active',
      'facilityApprovalLocked': false,
      'pharmacyType': 'External',
      'email': _email.text.trim(),
      'password': _password.text,
      'phone': _phone.text.trim(),
      'fullName': _fullName.text.trim(),
      'profileImageUrl': _profileImageBase64,
      'address': _locationPreviewLabel,
      'city': _city,
      'operatingHours': _operatingHoursPayload(),
      'licenseNumber': _licenseNumber.text.trim(),
    };
  }

  Map<String, dynamic> _buildInternalStaffPayload() {
    final lat = _marker?.latitude;
    final lng = _marker?.longitude;
    final hours = _operatingHoursPayload();
    final profileType = _isInternalPharmacy ? 'Internal' : 'External';
    final pharmacyProfile = <String, dynamic>{
        'pharmacyName': _pharmacyName.text.trim(),
        'address': _locationPreviewLabel,
        'city': _city,
        'licenseNumber': _licenseNumber.text.trim(),
        'operatingHours': hours,
        'is24Hours': _is24Hours,
        'licenseImage': _licenseImageLabel,
        'latitude': lat,
        'longitude': lng,
        'phone': _phone.text.trim(),
        'pharmacyType': profileType,
      };
    if (!_isInternalPharmacy) {
      pharmacyProfile['pharmacyCategory'] = 'Independent';
    }
    final payload = <String, dynamic>{
      'fullName': _fullName.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'password': _password.text,
      'profileImageUrl': _profileImageBase64,
      'pharmacyName': _pharmacyName.text.trim(),
      'address': _locationPreviewLabel,
      'city': _city,
      'licenseNumber': _licenseNumber.text.trim(),
      'operatingHours': hours,
      'is24Hours': _is24Hours,
      'licenseImage': _licenseImageLabel,
      'latitude': lat,
      'longitude': lng,
      'name': _fullName.text.trim(),
      'role': 'Pharmacist',
      'pharmacyType': profileType,
      'pharmacyProfile': pharmacyProfile,
    };
    if (_isInternalPharmacy) {
      final orgId = _orgId?.trim() ?? '';
      if (orgId.isNotEmpty) payload['orgId'] = orgId;
    }
    return payload;
  }

  void _resetForm() {
    _fullName.clear();
    _email.clear();
    _phone.clear();
    _password.clear();
    _confirmPassword.clear();
    _pharmacyName.clear();
    _licenseNumber.clear();
    _mapSearch.clear();
    _licenseImageLabel = '';
    _profileImageBase64 = '';
    _openDays.clear();
    _openTime = null;
    _closeTime = null;
    _is24Hours = false;
    _city = kPharmacyCities.first.name;
    setState(() {
      _marker = null;
      _locationPreviewLabel = '';
      _locationConfirmed = false;
    });
    _formKey.currentState?.reset();
  }

  String _parseApiError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return body.trim().isEmpty ? 'Registration failed. Please try again.' : body;
  }

  void _showGoldSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.urbanist(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AuthSignupColors.gold,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.urbanist()),
        backgroundColor: const Color(0xFFB71C1C),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isInternalPharmacy) {
      final orgId = _orgId?.trim() ?? '';
      if (orgId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your facility / organization')),
        );
        return;
      }
    }
    if (!_formKey.currentState!.validate()) return;

    final hoursErr = _validateOperatingHours();
    if (hoursErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hoursErr)));
      return;
    }

    if (_marker == null || !_locationConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Place and confirm your pharmacy location on the map')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_isInternalPharmacy) {
        final body = _buildInternalStaffPayload();
        final res = await http
            .post(
              Uri.parse('$rafeeqApiBase/signup'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 30));

        if (!mounted) return;
        if (res.statusCode == 200) {
          _showGoldSnackBar('Pharmacy registration submitted successfully for review!');
          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          rafeeqNavigateBackToHome(context);
        } else {
          _showErrorSnackBar(_parseApiError(res.body));
        }
        return;
      }

      final body = _buildExternalPharmacyPayload();
      final res = await http
          .post(
            Uri.parse('$rafeeqApiBase$_kExternalPharmacyRegisterPath'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        String msg = 'External pharmacy registered successfully.';
        try {
          final data = jsonDecode(res.body);
          if (data is Map && data['message'] is String) {
            msg = data['message'] as String;
          }
        } catch (_) {}
        _showGoldSnackBar(msg);
        _resetForm();
        setState(() => _submitting = false);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        rafeeqNavigateBackToHome(context);
      } else {
        _showErrorSnackBar(_parseApiError(res.body));
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Network error: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthSignupColors.scaffoldBlack,
      extendBodyBehindAppBar: true,
      appBar: AuthSignupTheme.authAppBar(context: context, title: 'Pharmacy Registration'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: AuthSignupTheme.gradientBackgroundDecoration()),
          Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Join Rafeeq as a licensed pharmacy',
                  style: GoogleFonts.urbanist(color: Colors.grey.shade400, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _section('Pharmacy affiliation', [
                  DropdownButtonFormField<String>(
                    value: _pharmacyType,
                    dropdownColor: const Color(0xFF1A2220),
                    style: AuthSignupTheme.fieldTextStyle(),
                    decoration: AuthSignupTheme.inputDecoration(
                      'Pharmacy type',
                      prefixIcon: Icons.store_mall_directory_outlined,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'External',
                        child: Text(
                          'External / Independent (community pharmacy)',
                          style: AuthSignupTheme.fieldTextStyle(),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Internal',
                        child: Text(
                          'Internal (clinic / hospital pharmacy)',
                          style: AuthSignupTheme.fieldTextStyle(),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _pharmacyType = v ?? 'External';
                        if (!_isInternalPharmacy) {
                          _orgId = null;
                          _orgName = '';
                        } else {
                          _orgId = _suggestedOrgId ?? _orgId;
                          _orgName = _suggestedOrgName.isNotEmpty ? _suggestedOrgName : _orgName;
                        }
                      });
                    },
                  ),
                  if (!_isInternalPharmacy) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Independent pharmacies register without linking to a clinic or hospital.',
                      style: GoogleFonts.urbanist(color: Colors.grey.shade400, fontSize: 13, height: 1.35),
                    ),
                  ],
                ]),
                if (_isInternalPharmacy) ...[
                  if (_orgName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Facility: $_orgName',
                        style: GoogleFonts.urbanist(color: AuthSignupColors.goldLight, fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _orgId,
                      dropdownColor: const Color(0xFF1A2220),
                      style: AuthSignupTheme.fieldTextStyle(),
                      decoration: AuthSignupTheme.inputDecoration(
                        'Facility / Organization',
                        prefixIcon: Icons.business_outlined,
                      ),
                      hint: Text('Select facility', style: TextStyle(color: Colors.grey.shade500)),
                      items: [
                        for (final raw in _orgs)
                          if (raw is Map && raw['_id'] != null)
                            DropdownMenuItem(
                              value: raw['_id'].toString(),
                              child: Text(raw['name']?.toString() ?? 'Org', style: AuthSignupTheme.fieldTextStyle()),
                            ),
                      ],
                      onChanged: (v) {
                        final name = _orgs.cast<Map>().firstWhere(
                              (o) => o['_id']?.toString() == v,
                              orElse: () => {},
                            )['name']?.toString();
                        setState(() {
                          _orgId = v;
                          _orgName = name ?? '';
                        });
                      },
                      validator: (v) =>
                          _isInternalPharmacy && (v == null || v.isEmpty) ? 'Facility is required' : null,
                    ),
                  const SizedBox(height: 4),
                ],
                _section('Profile photo', [
                  PharmacistProfilePhotoPicker(
                    imageData: _profileImageBase64,
                    onPick: _pickProfilePhoto,
                    radius: 48,
                  ),
                  pharmacistPhotoHint(),
                ]),
                _section('Account information', [
                  TextFormField(
                    controller: _fullName,
                    style: AuthSignupTheme.fieldTextStyle(),
                    decoration: AuthSignupTheme.inputDecoration('Full name', prefixIcon: Icons.person_outline),
                    validator: (v) => v == null || v.trim().length < 2 ? 'Enter your full name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: AuthSignupTheme.fieldTextStyle(),
                    decoration: AuthSignupTheme.inputDecoration('Email', prefixIcon: Icons.email_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    style: AuthSignupTheme.fieldTextStyle(),
                    decoration: AuthSignupTheme.inputDecoration('Phone number', prefixIcon: Icons.phone_outlined),
                    validator: (v) => v == null || v.trim().length < 8 ? 'Enter a valid phone' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    style: AuthSignupTheme.fieldTextStyle(),
                    decoration: AuthSignupTheme.inputDecoration('Password', prefixIcon: Icons.lock_outline),
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPassword,
                    obscureText: true,
                    style: AuthSignupTheme.fieldTextStyle(),
                    decoration: AuthSignupTheme.inputDecoration('Confirm password', prefixIcon: Icons.lock_reset),
                    validator: (v) {
                      if (v != _password.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ]),
                _section('Pharmacy information', [
                  TextFormField(
                    controller: _pharmacyName,
                    style: AuthSignupTheme.fieldTextStyle(),
                    decoration: AuthSignupTheme.inputDecoration('Pharmacy name', prefixIcon: Icons.local_pharmacy_outlined),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Pharmacy name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _city,
                    dropdownColor: const Color(0xFF1A2220),
                    style: AuthSignupTheme.fieldTextStyle(),
                    decoration: AuthSignupTheme.inputDecoration('City', prefixIcon: Icons.location_city_outlined),
                    items: kPharmacyCities
                        .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name, style: AuthSignupTheme.fieldTextStyle())))
                        .toList(),
                    onChanged: _onCityChanged,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _licenseNumber,
                    style: AuthSignupTheme.fieldTextStyle(),
                    decoration: AuthSignupTheme.inputDecoration('License number', prefixIcon: Icons.verified_outlined),
                    validator: (v) => v == null || v.trim().isEmpty ? 'License number is required' : null,
                  ),
                  const SizedBox(height: 12),
                  _operatingHoursSection(),
                ]),
                _section('Pharmacy location', [
                  Text(
                    'Pin your pharmacy on the map. Search or tap to place the gold marker — location is saved as coordinates only.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  PharmacyLocationPicker(
                    key: ValueKey(_city),
                    marker: _marker,
                    locationConfirmed: _locationConfirmed,
                    mapCenter: _mapCenter,
                    searchCityName: _city,
                    searchController: _mapSearch,
                    onMarkerChanged: _onMarkerChanged,
                    onLocationConfirmed: _confirmLocation,
                  ),
                ]),
                _section('Verification', [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AuthSignupColors.goldLight,
                      side: BorderSide(color: AuthSignupColors.gold.withValues(alpha: 0.7)),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    onPressed: () {
                      setState(() => _licenseImageLabel = 'pharmacy_license_placeholder.pdf');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('License upload — placeholder attached')),
                      );
                    },
                    icon: const Icon(Icons.upload_file, color: AuthSignupColors.gold),
                    label: Text(
                      _licenseImageLabel.isEmpty
                          ? 'Upload pharmacy license image'
                          : 'License: $_licenseImageLabel',
                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                AuthSignupTheme.primaryButton(
                  label: 'Sign Up',
                  onPressed: _submit,
                  loading: _submitting,
                ),
              ],
            ),
          ),
        ),
          ),
        ],
      ),
    );
  }
}
