import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../screens/auth/nurse_signup_screen.dart';
import '../../../signup_screen.dart';
import '../../../tenant_state.dart';
import '../../../widgets/looping_asset_video_background.dart';
import '../../../widgets/rafeeq_back_home_button.dart';
import 'auth_signup_theme.dart';
import 'clinical_technologist_signup_screen.dart';
import 'doctor_signup_screen.dart';
import 'pharmacy_signup_screen.dart';

/// Cinematic role gateway — looping hospital video with image-based role cards.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({
    super.key,
    this.presetOrgId,
    this.presetOrgName,
  });

  final String? presetOrgId;
  final String? presetOrgName;

  static const _roles = <_RoleOption>[
    _RoleOption(
      assetPath: 'assets/images/patient.jpg',
      route: _RoleRoute.patient,
    ),
    _RoleOption(
      assetPath: 'assets/images/doctor.webp',
      route: _RoleRoute.doctor,
    ),
    _RoleOption(
      assetPath: 'assets/images/pharm.avif',
      route: _RoleRoute.pharmacist,
    ),
    _RoleOption(
      assetPath: 'assets/images/nurse.avif',
      route: _RoleRoute.nurse,
    ),
    _RoleOption(
      assetPath: 'assets/images/lab tech.webp',
      route: _RoleRoute.labTech,
    ),
    _RoleOption(
      assetPath: 'assets/images/radio.webp',
      route: _RoleRoute.radio,
    ),
  ];

  static String _roleLabel(S l10n, _RoleRoute route) {
    switch (route) {
      case _RoleRoute.patient:
        return l10n.authRolePatient;
      case _RoleRoute.doctor:
        return l10n.authRoleDoctor;
      case _RoleRoute.pharmacist:
        return l10n.authRolePharmacist;
      case _RoleRoute.nurse:
        return l10n.authRoleNurse;
      case _RoleRoute.labTech:
        return l10n.authRoleLabTech;
      case _RoleRoute.radio:
        return l10n.authRoleRadiology;
    }
  }

  String? get _orgId {
    final preset = presetOrgId?.trim();
    if (preset != null && preset.isNotEmpty) return preset;
    final tenant = TenantState.instance.orgId.trim();
    return tenant.isNotEmpty ? tenant : null;
  }

  String? get _orgName {
    final preset = presetOrgName?.trim();
    if (preset != null && preset.isNotEmpty) return preset;
    final tenantName = TenantState.instance.theme.name.trim();
    return tenantName.isNotEmpty ? tenantName : null;
  }

  void _onRoleSelected(BuildContext context, _RoleOption role) {
    switch (role.route) {
      case _RoleRoute.patient:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SignupScreen(
              presetOrgId: _orgId,
              presetOrgName: _orgName,
              lockRoleTo: 'Patient',
            ),
          ),
        );
      case _RoleRoute.doctor:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => DoctorSignupScreen(
              presetOrgId: _orgId,
              presetOrgName: _orgName,
            ),
          ),
        );
      case _RoleRoute.pharmacist:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PharmacySignupScreen(
              presetOrgId: _orgId,
              presetOrgName: _orgName,
            ),
          ),
        );
      case _RoleRoute.nurse:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => NurseSignupScreen(
              presetOrgId: _orgId,
              presetOrgName: _orgName,
            ),
          ),
        );
      case _RoleRoute.labTech:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => LabTechnicianSignupScreen(
              presetOrgId: _orgId,
              presetOrgName: _orgName,
            ),
          ),
        );
      case _RoleRoute.radio:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => RadiologyTechnologistSignupScreen(
              presetOrgId: _orgId,
              presetOrgName: _orgName,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const LoopingAssetVideoBackground(
            assetPath: kHospitalBackgroundVideoAsset,
            loading: Center(child: CircularProgressIndicator(color: AuthSignupColors.gold)),
          ),
          Container(color: Colors.black.withValues(alpha: 0.65)),
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.35),
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: rafeeqBackHomeAppBarLeading(context),
              foregroundColor: AuthSignupColors.goldLight,
              title: Text(
                l10n.authSignUp,
                style: GoogleFonts.urbanist(
                  color: AuthSignupColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.authSelectYourRole,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(
                            color: AuthSignupColors.gold,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.authChooseHowToUse,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        if (_orgName != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AuthSignupColors.gold.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.apartment_rounded, color: AuthSignupColors.goldLight, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.authFacility(_orgName!),
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.78,
                          children: [
                            for (final role in _roles)
                              _RoleImageCard(
                                role: role,
                                label: _roleLabel(l10n, role.route),
                                onTap: () => _onRoleSelected(context, role),
                              ),
                          ],
                        ),
                      ],
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

enum _RoleRoute { patient, doctor, pharmacist, nurse, labTech, radio }

class _RoleOption {
  const _RoleOption({
    required this.assetPath,
    required this.route,
  });

  final String assetPath;
  final _RoleRoute route;
}

class _RoleImageCard extends StatelessWidget {
  const _RoleImageCard({
    required this.role,
    required this.label,
    required this.onTap,
  });

  final _RoleOption role;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(color: AuthSignupColors.gold.withValues(alpha: 0.75), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        role.assetPath,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person_outline,
                          size: 56,
                          color: AuthSignupColors.gold.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(
                      color: AuthSignupColors.goldLight,
                      fontSize: label.length > 14 ? 12.5 : 15,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
