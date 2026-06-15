import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'widgets/looping_asset_video_background.dart';

import 'api_config.dart';
import 'l10n/l10n_extensions.dart';
import 'facility_role_auth_screens.dart';
import 'tenant_state.dart';
import 'widgets/rafeeq_back_home_button.dart';

const Color _fdGold = Color(0xFFD4AF37);
const Color _fdGlass = Color(0x38FFFFFF);

String _str(dynamic v) => v == null ? '' : v.toString().trim();

String? _labelForModuleKey(String raw) {
  final k = raw.trim().toLowerCase();
  const map = <String, String>{
    'pharmacy': 'Pharmacy',
    'labradiology': 'Lab & Radiology',
    'lab_radiology': 'Lab & Radiology',
    'emergency': 'Emergency',
    'internstrainees': 'Intern / Trainee',
    'interns_trainees': 'Intern / Trainee',
    'intern': 'Intern / Trainee',
    'trainee': 'Intern / Trainee',
  };
  return map[k] ?? (raw.isNotEmpty ? raw : null);
}

List<String> _modulesFromOrg(Map<String, dynamic> o) {
  final keys = o['moduleKeys'];
  if (keys is List && keys.isNotEmpty) {
    final out = <String>{};
    for (final e in keys) {
      final lab = _labelForModuleKey(e.toString());
      if (lab != null) out.add(lab);
    }
    if (out.isNotEmpty) return out.toList()..sort();
  }
  final am = o['activeModules'];
  if (am is! Map) return [];
  final list = <String>[];
  if (am['pharmacy'] == true) list.add('Pharmacy');
  if (am['labRadiology'] == true) list.add('Lab & Radiology');
  if (am['internsTrainees'] == true) list.add('Intern / Trainee');
  if (am['emergency'] == true) list.add('Emergency');
  return list;
}

bool _orgOffersModule(Map<String, dynamic> o, String label) =>
    _modulesFromOrg(o).contains(label);

/// Full-screen organization profile: loads `GET /api/organizations/:id` (complete org document).
class FacilityDetailsScreen extends StatefulWidget {
  const FacilityDetailsScreen({
    super.key,
    required this.organizationId,
    this.branchDisplayName,
  });

  final String organizationId;
  final String? branchDisplayName;

  @override
  State<FacilityDetailsScreen> createState() => _FacilityDetailsScreenState();
}

class _FacilityDetailsScreenState extends State<FacilityDetailsScreen> {
  final _scroll = ScrollController();

  bool _loading = true;
  String? _httpError;
  Map<String, dynamic>? _org;

  @override
  void initState() {
    super.initState();
    _loadOrg();
  }

  Future<void> _loadOrg() async {
    final id = widget.organizationId.trim();
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _httpError = 'Missing organization id';
      });
      return;
    }
    setState(() {
      _loading = true;
      _httpError = null;
    });
    try {
      final r = await http
          .get(Uri.parse('$rafeeqApiBase/api/organizations/$id'))
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (r.statusCode != 200) {
        String msg = r.body;
        try {
          final j = jsonDecode(r.body);
          if (j is Map && j['message'] is String) msg = j['message'] as String;
        } catch (_) {}
        setState(() {
          _loading = false;
          _httpError = msg;
        });
        return;
      }
      final decoded = jsonDecode(r.body);
      if (decoded is! Map) {
        setState(() {
          _loading = false;
          _httpError = 'Invalid response';
        });
        return;
      }
      final orgDoc = Map<String, dynamic>.from(decoded);
      TenantState.instance.setFromOrgPayload(id, orgDoc);
      try {
        final clinicsRes = await http
            .get(Uri.parse('$rafeeqApiBase/api/clinics?orgId=$id'))
            .timeout(const Duration(seconds: 12));
        if (clinicsRes.statusCode == 200) {
          final clinics = jsonDecode(clinicsRes.body);
          if (clinics is List && clinics.isNotEmpty && clinics.first is Map) {
            final firstId = (clinics.first as Map)['_id']?.toString();
            if (firstId != null && firstId.isNotEmpty) {
              await TenantState.instance.setPreferredClinicId(firstId);
            }
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _org = orgDoc;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _httpError = e.toString();
      });
    }
  }

  Future<void> _openMapUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    final uri = Uri.tryParse(u);
    if (uri == null || !(uri.hasScheme)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.authInvalidMapLink)),
        );
      }
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.authCouldNotOpenMap)),
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _glassPanel({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [_fdGlass, Colors.white.withValues(alpha: 0.06)],
            ),
            border: Border.all(color: _fdGold.withValues(alpha: 0.92), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LoopingAssetVideoBackground(
            assetPath: kHospitalBackgroundVideoAsset,
            loading: const Center(
              child: CircularProgressIndicator(color: _fdGold),
            ),
            errorBuilder: (context, initError, playerError) {
              return Center(
                child: Text(
                  'Video unavailable',
                  style: GoogleFonts.poppins(color: Colors.white54),
                ),
              );
            },
          ),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: rafeeqBackHomeAppBarLeading(context),
              foregroundColor: Colors.white,
              title: Text(
                'Facility details',
                style: GoogleFonts.playfairDisplay(color: _fdGold, fontWeight: FontWeight.w600),
              ),
            ),
            body: SafeArea(
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(48),
                              child: Center(child: CircularProgressIndicator(color: _fdGold)),
                            )
                          : _httpError != null
                              ? _glassPanel(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Could not load facility',
                                        style: GoogleFonts.playfairDisplay(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _httpError!,
                                        style: GoogleFonts.poppins(color: Colors.white70, height: 1.4),
                                      ),
                                      const SizedBox(height: 20),
                                      FilledButton(
                                        onPressed: _loadOrg,
                                        style: FilledButton.styleFrom(backgroundColor: _fdGold, foregroundColor: Colors.black),
                                        child: Text(context.l10n.adminRetry),
                                      ),
                                    ],
                                  ),
                                )
                              : _buildContent(context),
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

  Widget _buildContent(BuildContext context) {
    final o = _org!;
    final name = _str(o['name']);
    final branch = widget.branchDisplayName?.trim();
    final logo = _str(o['logoUrl']);
    final description = _str(o['description']);
    final phone = _str(o['phone']);
    final address = _str(o['address']);
    final city = _str(o['city']);
    var lineAddress = address;
    var lineCity = city;
    final loc = o['location'];
    if (loc is Map) {
      if (lineAddress.isEmpty) lineAddress = _str(loc['address']);
      if (lineCity.isEmpty) lineCity = _str(loc['city']);
    }
    final mapUrl = _str(o['mapUrl']);
    final modules = _modulesFromOrg(o);
    final facilityId = _str(o['_id']).isNotEmpty ? _str(o['_id']) : widget.organizationId;

    Uri? logoUri;
    if (logo.isNotEmpty) {
      try {
        logoUri = Uri.parse(logo);
        if (!logoUri.hasScheme) logoUri = null;
      } catch (_) {
        logoUri = null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _glassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: logoUri != null
                      ? Image.network(
                          logoUri.toString(),
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) => ColoredBox(
                            color: Colors.teal.withValues(alpha: 0.3),
                            child: Icon(Icons.local_hospital_rounded, color: _fdGold.withValues(alpha: 0.85), size: 56),
                          ),
                        )
                      : ColoredBox(
                          color: Colors.teal.withValues(alpha: 0.3),
                          child: Icon(Icons.local_hospital_rounded, color: _fdGold.withValues(alpha: 0.85), size: 56),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name.isEmpty ? 'Facility' : name,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (branch != null && branch.isNotEmpty && branch != name) ...[
                const SizedBox(height: 6),
                Text(
                  branch,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: _fdGold.withValues(alpha: 0.95),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (description.isNotEmpty)
          _glassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: GoogleFonts.playfairDisplay(
                    color: _fdGold,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        if (description.isNotEmpty) const SizedBox(height: 18),
        _buildChooseRoleSection(context, o, facilityId),
        const SizedBox(height: 18),
        _glassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Facilities & departments',
                style: GoogleFonts.playfairDisplay(
                  color: _fdGold,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (modules.isEmpty)
                Text(
                  'No modules listed for this organization.',
                  style: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in modules)
                      Chip(
                        label: Text(m, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        side: const BorderSide(color: _fdGold, width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _glassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact & location',
                style: GoogleFonts.playfairDisplay(
                  color: _fdGold,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (phone.isNotEmpty)
                _contactRow(Icons.phone_outlined, phone),
              if (lineAddress.isNotEmpty) ...[
                if (phone.isNotEmpty) const SizedBox(height: 8),
                _contactRow(Icons.place_outlined, lineAddress),
              ],
              if (lineCity.isNotEmpty) ...[
                const SizedBox(height: 8),
                _contactRow(Icons.location_city_outlined, lineCity),
              ],
              if (mapUrl.isNotEmpty) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => _openMapUrl(mapUrl),
                  icon: const Icon(Icons.map_outlined, color: _fdGold),
                  label: Text(
                    'Open map / directions',
                    style: GoogleFonts.poppins(
                      color: _fdGold,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: _fdGold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _bindTenantAndOpen(Widget page, Map<String, dynamic> orgDoc) {
    final oid = _str(orgDoc['_id']).isNotEmpty ? _str(orgDoc['_id']) : widget.organizationId;
    TenantState.instance.setFromOrgPayload(oid, orgDoc);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _roleActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    double? width,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(color: _fdGold.withValues(alpha: 0.85), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: _fdGold, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _fdGold.withValues(alpha: 0.9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChooseRoleSection(BuildContext context, Map<String, dynamic> o, String facilityId) {
    final hasPharmacy = _orgOffersModule(o, 'Pharmacy');
    final hasLabRad = _orgOffersModule(o, 'Lab & Radiology');
    final hasEmergency = _orgOffersModule(o, 'Emergency');

    return _glassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your role to enter this facility',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: _fdGold,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Static roles are always available. Additional roles appear when this facility enables the matching department.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final useTwoCol = maxW >= 460;
              final tileW = useTwoCol ? (maxW - 10) / 2 : maxW;

              Widget sized(Widget child) =>
                  SizedBox(width: tileW, child: child);

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  sized(
                    _roleActionCard(
                      icon: Icons.person_outline_rounded,
                      title: context.l10n.authPortalPatient,
                      subtitle: context.l10n.authPortalPatientSubtitle,
                      onTap: () => _bindTenantAndOpen(PatientAuthScreen(facilityId: facilityId), o),
                    ),
                  ),
                  sized(
                    _roleActionCard(
                      icon: Icons.medical_services_outlined,
                      title: context.l10n.authPortalDoctor,
                      subtitle: context.l10n.authPortalDoctorSubtitle,
                      onTap: () => _bindTenantAndOpen(DoctorAuthScreen(facilityId: facilityId), o),
                    ),
                  ),
                  if (hasPharmacy)
                    sized(
                      _roleActionCard(
                        icon: Icons.local_pharmacy_outlined,
                        title: context.l10n.authPortalPharmacist,
                        subtitle: context.l10n.authPortalPharmacistSubtitle,
                        onTap: () => _bindTenantAndOpen(PharmacistAuthScreen(facilityId: facilityId), o),
                      ),
                    ),
                  if (hasLabRad) ...[
                    sized(
                      _roleActionCard(
                        icon: Icons.biotech_outlined,
                        title: context.l10n.authPortalLabTech,
                        subtitle: context.l10n.authPortalLabTechSubtitle,
                        onTap: () => _bindTenantAndOpen(LabTechnicianAuthScreen(facilityId: facilityId), o),
                      ),
                    ),
                    sized(
                      _roleActionCard(
                        icon: Icons.monitor_heart_outlined,
                        title: context.l10n.authPortalRadiologist,
                        subtitle: context.l10n.authPortalRadiologistSubtitle,
                        onTap: () => _bindTenantAndOpen(RadiologistAuthScreen(facilityId: facilityId), o),
                      ),
                    ),
                  ],
                  if (hasEmergency)
                    sized(
                      _roleActionCard(
                        icon: Icons.emergency_outlined,
                        title: context.l10n.authPortalEmergency,
                        subtitle: context.l10n.authPortalEmergencySubtitle,
                        onTap: () => _bindTenantAndOpen(EmergencyStaffAuthScreen(facilityId: facilityId), o),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _fdGold, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.92), fontSize: 15, height: 1.35),
          ),
        ),
      ],
    );
  }
}
