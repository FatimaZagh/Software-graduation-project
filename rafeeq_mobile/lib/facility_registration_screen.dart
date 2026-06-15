import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'widgets/facility_location_picker.dart';
import 'widgets/looping_asset_video_background.dart';
import 'features/auth/services/nominatim_service.dart';

import 'api_config.dart';
import 'l10n/l10n_extensions.dart';
import 'tenant_state.dart';
import 'widgets/rafeeq_back_home_button.dart';

const Color _fxGold = Color(0xFFD4AF37);
const Color _fxGlass = Color(0x38FFFFFF);

/// Module keys must match backend `moduleKeysToActiveModules` mapping.
const List<(String id, String label)> _kFacilityModules = [
  ('pharmacy', 'Pharmacy'),
  ('labRadiology', 'Lab & Radiology'),
  ('emergency', 'Emergency'),
  ('internsTrainees', 'Intern / Trainee'),
];

class _DashedGoldBorderPainter extends CustomPainter {
  _DashedGoldBorderPainter({required this.color, this.radius = 12});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      const dash = 7.0;
      const gap = 5.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedGoldBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class FacilityRegistrationScreen extends StatefulWidget {
  const FacilityRegistrationScreen({super.key});

  @override
  State<FacilityRegistrationScreen> createState() => _FacilityRegistrationScreenState();
}

class _FacilityRegistrationScreenState extends State<FacilityRegistrationScreen> {
  final _scroll = ScrollController();

  final _clinicName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _mapUrl = TextEditingController();
  final _description = TextEditingController();
  final _adminName = TextEditingController();
  final _adminEmail = TextEditingController();
  final _adminPassword = TextEditingController();

  final Set<String> _selectedModules = {};
  bool _hasInternalPharmacy = true;
  String _logoBase64 = '';
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _locationConfirmed = false;
  String _locationPreview = '';
  static const LatLng _defaultMapCenter = LatLng(32.2211, 35.2544);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _clinicName.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _mapUrl.dispose();
    _description.dispose();
    _adminName.dispose();
    _adminEmail.dispose();
    _adminPassword.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 88,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final mime = x.mimeType?.startsWith('image/png') == true ? 'image/png' : 'image/jpeg';
    final b64 = base64Encode(bytes);
    setState(() => _logoBase64 = 'data:$mime;base64,$b64');
    if (kDebugMode) debugPrint('[facility-register] logo picked, ${bytes.length} bytes');
  }

  void _onLocationConfirmed(NominatimReverseResult result) {
    setState(() {
      _locationConfirmed = true;
      _locationPreview = result.displayName;
      _address.text = result.formattedAddress;
      _mapUrl.text = result.googleMapsUrl;
      if (result.city.trim().isNotEmpty) {
        _city.text = result.city.trim();
      }
    });
    if (kDebugMode) {
      debugPrint('[facility-register] location confirmed: ${result.googleMapsUrl}');
    }
  }

  Widget _facilityImageUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Facility image',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: _fxGold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickLogo,
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(
              painter: _DashedGoldBorderPainter(
                color: _fxGold.withValues(alpha: 0.92),
                radius: 16,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _logoBase64.isEmpty
                    ? Column(
                        children: [
                          CustomPaint(
                            painter: _DashedGoldBorderPainter(
                              color: _fxGold.withValues(alpha: 0.9),
                              radius: 14,
                            ),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: Icon(
                                Icons.add_a_photo_outlined,
                                color: _fxGold.withValues(alpha: 0.95),
                                size: 34,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'Upload facility logo or cover',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to choose from gallery',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(_logoBase64.split(',').last),
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preview ready',
                                style: GoogleFonts.poppins(
                                  color: _fxGold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to replace image',
                                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.edit_outlined, color: _fxGold.withValues(alpha: 0.9)),
                      ],
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _credRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _fxGold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label, style: GoogleFonts.poppins(color: _fxGold, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.35),
      labelStyle: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9)),
      hintStyle: GoogleFonts.poppins(color: Colors.white38),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _fxGold.withValues(alpha: 0.65), width: 1.35),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _fxGold, width: 1.85),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _clinicName.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.authFacilityNameRequired)),
      );
      return;
    }
    if (!_locationConfirmed || _address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.authConfirmLocation)),
      );
      return;
    }
    if (_adminName.text.trim().isEmpty ||
        _adminEmail.text.trim().isEmpty ||
        _adminPassword.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.authCompleteAdminFields)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final body = jsonEncode({
        'name': name,
        'logoUrl': _logoBase64,
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'mapUrl': _mapUrl.text.trim(),
        'description': _description.text.trim(),
        'activeModuleKeys': _selectedModules.toList(),
        'hasInternalPharmacy': _selectedModules.contains('pharmacy') && _hasInternalPharmacy,
        'adminName': _adminName.text.trim(),
        'adminEmail': _adminEmail.text.trim(),
        'adminPassword': _adminPassword.text,
      });

      if (kDebugMode) debugPrint('[facility-register] POST /api/organizations/register');

      final r = await http
          .post(
            Uri.parse('$rafeeqApiBase/api/organizations/register'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (kDebugMode) debugPrint('[facility-register] response ${r.statusCode}');

      if (!mounted) return;

      if (r.statusCode == 201) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final orgId = data['orgId']?.toString() ?? '';
        if (orgId.isEmpty) {
          throw Exception('Invalid server response');
        }

        try {
          final tr = await http
              .get(Uri.parse('$rafeeqApiBase/api/organizations/$orgId/theme'))
              .timeout(const Duration(seconds: 15));
          if (tr.statusCode == 200) {
            TenantState.instance.setFromOrgPayload(orgId, jsonDecode(tr.body));
          } else {
            TenantState.instance.setFromOrgPayload(orgId, data['organization'] ?? {'name': name});
          }
        } catch (_) {
          TenantState.instance.setFromOrgPayload(orgId, data['organization'] ?? {'name': name});
        }

        if (!mounted) return;

        final creds = data['internalPharmacyCredentials'];
        final hasInternalCreds = creds is Map && creds['email'] != null;

        if (hasInternalCreds) {
          final email = creds['email']?.toString() ?? '';
          final password = creds['password']?.toString() ?? '123456';
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _fxGold.withValues(alpha: 0.5)),
              ),
              title: Text(
                'تم إنشاء حساب الصيدلية الداخلية بنجاح!',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.w700,
                  color: _fxGold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.right,
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'لكي يقوم الصيدلاني بالدخول، يرجى استخدام البيانات التالية:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 16),
                    _credRow('الإيميل', email),
                    const SizedBox(height: 10),
                    _credRow('الرمز السري', password),
                    const SizedBox(height: 12),
                    Text(
                      'سيتم تفعيل حساب مدير المنشأة بعد موافقة المشرف. يمكن للصيدلاني الدخول مباشرة إلى لوحة المخزون.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white54, height: 1.35),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('حسناً', style: GoogleFonts.poppins(color: _fxGold, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        } else {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(
                'Registration received',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              content: SingleChildScrollView(
                child: Text(
                  'Your clinic is under review. Please wait for Super Admin activation. '
                  'You can sign in with your admin email once the facility is approved.',
                  style: GoogleFonts.poppins(fontSize: 14, height: 1.4, color: Colors.black87),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      String msg = r.body;
      try {
        final err = jsonDecode(r.body);
        if (err is Map && err['message'] is String) msg = err['message'] as String;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (kDebugMode) debugPrint('[facility-register] error $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: rafeeqBackHomeAppBarLeading(context),
        foregroundColor: Colors.white,
        title: Text(
          'Facility registration',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600,
            color: _fxGold,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          LoopingAssetVideoBackground(
            assetPath: kHospitalBackgroundVideoAsset,
            loading: const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
            errorBuilder: (context, initError, playerError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    initError != null
                        ? 'Video failed to load.'
                        : (playerError ?? 'Video error'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  ),
                ),
              );
            },
          ),
          // Same asset + mood as landing hero; slightly stronger tint for dense form readability.
          Container(color: Colors.black.withValues(alpha: 0.42)),
          SafeArea(
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_fxGlass, Colors.white.withValues(alpha: 0.06)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: _fxGold.withValues(alpha: 0.9), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            Text(
                              'Register your facility',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your organization and primary admin login in one step.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(height: 22),

                            TextField(
                              controller: _clinicName,
                              style: GoogleFonts.poppins(color: Colors.white),
                              decoration: _dec('Clinic / hospital name *'),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),

                            Text(
                              'Services & departments',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color: _fxGold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final m in _kFacilityModules)
                                  FilterChip(
                                    label: Text(m.$2),
                                    selected: _selectedModules.contains(m.$1),
                                    onSelected: (sel) => setState(() {
                                      if (sel) {
                                        _selectedModules.add(m.$1);
                                      } else {
                                        _selectedModules.remove(m.$1);
                                      }
                                    }),
                                    selectedColor: _fxGold.withValues(alpha: 0.35),
                                    checkmarkColor: Colors.black,
                                    labelStyle: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    side: const BorderSide(color: _fxGold),
                                  ),
                              ],
                            ),
                            if (_selectedModules.contains('pharmacy')) ...[
                              const SizedBox(height: 10),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'In-house clinic pharmacy',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                                ),
                                subtitle: Text(
                                  'Seed master drug inventory when facility is approved',
                                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                                ),
                                value: _hasInternalPharmacy,
                                activeThumbColor: _fxGold,
                                activeTrackColor: _fxGold.withValues(alpha: 0.45),
                                onChanged: (v) => setState(() => _hasInternalPharmacy = v),
                              ),
                            ],
                            const SizedBox(height: 16),

                            TextField(
                              controller: _phone,
                              style: GoogleFonts.poppins(color: Colors.white),
                              keyboardType: TextInputType.phone,
                              decoration: _dec('Contact phone'),
                            ),
                            const SizedBox(height: 18),

                            FacilityLocationPicker(
                              mapCenter: _defaultMapCenter,
                              searchCityName: _city.text.trim(),
                              locationConfirmed: _locationConfirmed,
                              confirmedPreview: _locationPreview,
                              onLocationConfirmed: _onLocationConfirmed,
                              mapHeight: 360,
                            ),
                            const SizedBox(height: 18),
                            _facilityImageUpload(),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _city,
                              style: GoogleFonts.poppins(color: Colors.white),
                              decoration: _dec('City'),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _description,
                              style: GoogleFonts.poppins(color: Colors.white),
                              minLines: 4,
                              maxLines: 8,
                              decoration: _dec('Detailed description'),
                            ),
                            const SizedBox(height: 22),

                            Text(
                              'Primary admin account',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color: _fxGold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _adminName,
                              style: GoogleFonts.poppins(color: Colors.white),
                              decoration: _dec('Admin full name *'),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _adminEmail,
                              style: GoogleFonts.poppins(color: Colors.white),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _dec('Admin email *'),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _adminPassword,
                              obscureText: _obscurePassword,
                              style: GoogleFonts.poppins(color: Colors.white),
                              decoration: _dec('Admin password *').copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _fxGold),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),

                            const SizedBox(height: 26),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _fxGold,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: _submitting ? null : _submit,
                                child: _submitting
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                      )
                                    : Text(
                                        'Submit & open dashboard',
                                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
