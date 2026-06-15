import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart';
import 'signup_screen.dart';
import 'tenant_state.dart';
import 'widgets/rafeeq_back_home_button.dart';

const Color _roleAuthGold = Color(0xFFD4AF37);
const Color _roleAuthGlass = Color(0x38FFFFFF);

/// Shared shell: tenant is expected to be set by the caller (e.g. [FacilityDetailsScreen]) before navigation.
class _RoleAuthShell extends StatelessWidget {
  const _RoleAuthShell({
    required this.facilityId,
    required this.title,
    required this.subtitle,
    required this.signupRole,
  });

  final String facilityId;
  final String title;
  final String subtitle;
  final String signupRole;

  @override
  Widget build(BuildContext context) {
    final facilityName = TenantState.instance.theme.name.trim();
    final orgLabel = facilityName.isEmpty ? 'This facility' : facilityName;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A18),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: rafeeqBackHomeAppBarLeading(context),
        title: Text(
          title,
          style: GoogleFonts.playfairDisplay(
            color: _roleAuthGold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [_roleAuthGlass, Colors.white.withValues(alpha: 0.06)],
                          ),
                          border: Border.all(color: _roleAuthGold.withValues(alpha: 0.9), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              orgLabel,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 22),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: _roleAuthGold,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                                );
                              },
                              child: Text(
                                'Log in',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: _roleAuthGold, width: 1.5),
                                foregroundColor: _roleAuthGold,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SignupScreen(
                                      presetOrgId: facilityId,
                                      presetOrgName: orgLabel,
                                      lockRoleTo: signupRole,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                'Register',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Organization (facility) id from the public facility profile route.
class PatientAuthScreen extends StatelessWidget {
  const PatientAuthScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context) {
    return _RoleAuthShell(
      facilityId: facilityId,
      title: 'Patient',
      subtitle: 'Sign in or create an account as a patient at this facility.',
      signupRole: 'Patient',
    );
  }
}

class DoctorAuthScreen extends StatelessWidget {
  const DoctorAuthScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context) {
    return _RoleAuthShell(
      facilityId: facilityId,
      title: 'Doctor',
      subtitle: 'Sign in or submit your registration request as a physician at this facility.',
      signupRole: 'Doctor',
    );
  }
}

class PharmacistAuthScreen extends StatelessWidget {
  const PharmacistAuthScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context) {
    return _RoleAuthShell(
      facilityId: facilityId,
      title: 'Pharmacist',
      subtitle: 'Sign in or request access as pharmacy staff for this facility.',
      signupRole: 'Pharmacist',
    );
  }
}

class LabTechnicianAuthScreen extends StatelessWidget {
  const LabTechnicianAuthScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context) {
    return _RoleAuthShell(
      facilityId: facilityId,
      title: 'Lab technician',
      subtitle: 'Sign in or request access as laboratory staff for this facility.',
      signupRole: 'Lab Technician',
    );
  }
}

class RadiologistAuthScreen extends StatelessWidget {
  const RadiologistAuthScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context) {
    return _RoleAuthShell(
      facilityId: facilityId,
      title: 'Radiologist',
      subtitle: 'Sign in or request access as imaging / radiology staff for this facility.',
      signupRole: 'Radiologist',
    );
  }
}

/// Uses backend role [Staff/Operations] (emergency-capable operations staff).
class EmergencyStaffAuthScreen extends StatelessWidget {
  const EmergencyStaffAuthScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context) {
    return _RoleAuthShell(
      facilityId: facilityId,
      title: 'Emergency staff',
      subtitle: 'Sign in or request access as emergency / operations staff for this facility.',
      signupRole: 'Staff/Operations',
    );
  }
}
