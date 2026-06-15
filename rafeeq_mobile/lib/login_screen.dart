import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'widgets/looping_asset_video_background.dart';

import 'api_config.dart';
import 'tenant_state.dart';
import 'super_admin/platform_super_admin_session.dart';
import 'super_admin/super_admin_dashboard_screen.dart';
import 'features/doctor_dashboard/presentation/doctor_dashboard_shell.dart';
import 'features/auth/presentation/role_selection_screen.dart';
import 'features/doctor_dashboard/data/doctor_session.dart';
import 'features/admin_dashboard/data/org_admin_session.dart';
import 'features/admin_dashboard/presentation/admin_dashboard_shell.dart';
import 'discover_facilities_screen.dart';
import 'features/nurse_dashboard/data/nurse_session.dart';
import 'features/diagnostic/data/technician_session.dart';
import 'features/nurse_dashboard/presentation/nurse_dashboard_shell.dart';
import 'features/pharmacist_dashboard/data/pharmacist_session.dart';
import 'features/pharmacist_dashboard/presentation/pharmacist_enterprise_shell.dart';
import 'role_dashboards/staff_placeholder_dashboards.dart';
import 'widgets/rafeeq_back_home_button.dart';
import 'widgets/responsive_layout.dart';
import 'l10n/l10n_extensions.dart';
import 'widgets/rafeeq_language_toggle.dart';

/// Backend `/login` 403 body when an Organization Admin's facility is not yet approved.
const String _kPendingFacilityLoginServerMessage =
    'Your facility registration request is still pending approval from the Super Admin.';

class _LuxuryColors {
  static const Color deepTealDark = Color(0xFF062A26);
  static const Color goldLight = Color(0xFFFFE8A3);
  static const Color goldMid = Color(0xFFD4AF37);
  static const Color goldDeep = Color(0xFFB8860B);
  static const Color glassEmerald = Color(0xCC004D40);
  static const Color marble1 = Color(0xE61A1A1A);
  static const Color marble2 = Color(0xE6282828);
  static const Color marble3 = Color(0xE61E1E1E);

  static const LinearGradient goldShimmer = LinearGradient(
    colors: [goldLight, goldMid, goldDeep, goldMid, goldLight],
    stops: [0.0, 0.28, 0.5, 0.72, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const List<BoxShadow> loginGoldGlow = [
    BoxShadow(color: Color(0x99FFD700), blurRadius: 28, spreadRadius: 0),
    BoxShadow(color: Color(0x66D4AF37), blurRadius: 42, spreadRadius: 4),
    BoxShadow(color: Color(0x44FFE082), blurRadius: 18, spreadRadius: -2),
  ];
}

class _GeometricPatternPainter extends CustomPainter {
  _GeometricPatternPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const step = 28.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), stroke);
    }
    for (double x = 0.0; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), stroke);
    }

    final dot = Paint()..color = lineColor.withValues(alpha: 0.35);
    for (double x = step / 2; x < size.width; x += step * 2) {
      for (double y = step / 2; y < size.height; y += step * 2) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GeometricPatternPainter oldDelegate) => oldDelegate.lineColor != lineColor;
}

Widget _goldGradientText(
  String text, {
  required TextStyle style,
  TextAlign? textAlign,
  bool glow = false,
}) {
  final glowStyle = glow
      ? style.copyWith(
          shadows: [
            Shadow(color: _LuxuryColors.goldMid.withValues(alpha: 0.55), blurRadius: 18),
            Shadow(color: _LuxuryColors.goldLight.withValues(alpha: 0.22), blurRadius: 28),
          ],
        )
      : style;
  return ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => _LuxuryColors.goldShimmer.createShader(bounds),
    child: Text(text, textAlign: textAlign, style: glowStyle.copyWith(color: Colors.white)),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  bool _rememberMe = true;
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _completeAuthFlow(http.Response response) async {
    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String? role = data['role'] as String?;
      final String? userId = data['id'] as String?;
      final String orgId = (data['orgId'] as String?) ?? '';

      if (role == 'SuperAdmin') {
        final tok = data['token'] as String?;
        final platform = data['platformSuperAdmin'] == true;
        if (tok == null || tok.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.loginSuperAdminMissingToken)),
          );
          return;
        }
        PlatformSuperAdminSession.setToken(tok);
        if (kDebugMode) {
          debugPrint('[login] Super Admin JWT stored (platformSuperAdmin=$platform)');
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => const SuperAdminDashboardScreen()),
        );
        return;
      }

      if (orgId.isNotEmpty) {
        TenantState.instance.orgId = orgId;
        await TenantState.instance.persistOrgId();
        try {
          final r = await http
              .get(Uri.parse('$rafeeqApiBase/api/organizations/$orgId/theme'))
              .timeout(const Duration(seconds: 12));
          if (r.statusCode == 200) {
            TenantState.instance.setFromOrgPayload(orgId, jsonDecode(r.body));
          }
        } catch (_) {}
        if (!mounted) return;
      }

      if (role == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.loginRoleMissing)),
        );
        return;
      }

      if ((role == 'Patient' || role == 'Doctor') && (userId == null || userId.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.loginUserIdMissing)),
        );
        return;
      }

      Widget destination;
      switch (role) {
        case 'Organization Admin':
          if (userId == null || userId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.loginUserIdMissing)),
            );
            return;
          }
          final adminName = data['name']?.toString() ?? data['fullName']?.toString() ?? '';
          final adminClinicId = data['clinicId']?.toString();
          await OrgAdminSession.instance.save(
            userId: userId,
            orgId: orgId,
            name: adminName,
            clinicId: adminClinicId,
          );
          destination = AdminDashboardShell(adminUserId: userId, adminName: adminName.isEmpty ? null : adminName);
          break;
        case 'Doctor':
          if (orgId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.loginOrgIdMissingDoctor),
              ),
            );
            return;
          }
          await DoctorSession.instance.save(token: data['token'] as String?);
          destination = DoctorDashboardShell(doctorUserId: userId!, doctorName: data['name']?.toString());
          break;
        case 'Nurse':
          if (userId == null || userId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.loginUserIdMissing)),
            );
            return;
          }
          final nurseName = data['name']?.toString() ?? '';
          await NurseSession.instance.save(userId: userId, orgId: orgId, name: nurseName);
          destination = NurseDashboardShell(nurseUserId: userId, nurseName: nurseName.isEmpty ? null : nurseName);
          break;
        case 'Lab Technician':
        case 'LabTechnician':
          if (orgId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.loginOrgIdMissingDoctor),
              ),
            );
            return;
          }
          final labTechName = data['name']?.toString() ?? data['fullName']?.toString() ?? '';
          await TechnicianSession.instance.save(
            userId: userId!,
            orgId: orgId,
            name: labTechName,
            role: role,
          );
          destination = LabTechnicianDashboard(
            userId: userId,
            userName: labTechName.isEmpty ? null : labTechName,
          );
          break;
        case 'Radiologist':
        case 'Radiology Technologist':
        case 'Radiology Technician':
        case 'Radiology Tech':
          if (userId == null || userId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.loginUserIdMissing)),
            );
            return;
          }
          if (orgId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.loginOrgIdMissingDoctor),
              ),
            );
            return;
          }
          final radName = data['name']?.toString() ?? data['fullName']?.toString() ?? '';
          await TechnicianSession.instance.save(
            userId: userId,
            orgId: orgId,
            name: radName,
            role: role == 'Radiologist' ? role : 'Radiologist',
          );
          destination = RadiologistDashboard(
            userId: userId,
            userName: radName.isEmpty ? null : radName,
          );
          break;
        case 'Pharmacist':
        case 'InternalPharmacist':
          if (userId == null || userId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.loginUserIdMissing)),
            );
            return;
          }
          final pharmacistName = data['name']?.toString();
          await PharmacistSession.instance.save(
            userId: userId,
            orgId: orgId,
            name: pharmacistName,
            token: data['token'] as String?,
          );
          destination = PharmacistInventoryDashboard(
            userId: userId,
            pharmacyName: pharmacistName,
          );
          break;
        case 'Intern/Trainee':
          destination = InternTraineeDashboard(userId: userId!);
          break;
        case 'Staff/Operations':
          destination = StaffOperationsDashboard(userId: userId!);
          break;
        case 'Patient':
          destination = DiscoverFacilitiesScreen(patientUserId: userId!);
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.loginUnknownRole(role))),
          );
          return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } else if (response.statusCode == 403) {
      String message = response.body;
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] is String) {
          message = data['message'] as String;
        }
      } catch (_) {}
      if (!mounted) return;
      if (message == _kPendingFacilityLoginServerMessage) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.loginClinicUnderReview),
            content: SingleChildScrollView(
              child: Text(
                context.l10n.loginClinicUnderReviewMessage,
                style: TextStyle(color: Colors.grey.shade800, height: 1.35),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(context.l10n.loginOk),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } else if (response.statusCode == 401) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.loginInvalidCredentials)),
      );
    } else if (response.statusCode == 404) {
      String message = response.body;
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] is String) message = data['message'] as String;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } else {
      String message = response.body;
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data["message"] is String) {
          message = data["message"] as String;
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.loginFailedMessage(message))),
      );
    }
  }

  Future<void> loginWithEmail() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse('$rafeeqApiBase/api/auth/login'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "loginMethod": "email",
              "email": emailController.text.trim(),
              "password": passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 15));
      await _completeAuthFlow(response);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.loginConnectionFailed)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> loginWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final google = GoogleSignIn(scopes: const ['email', 'openid']);
      final account = await google.signIn();
      final auth = await account?.authentication;
      final idToken = auth?.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.loginGoogleTokenFailed)),
        );
        return;
      }
      final response = await http
          .post(
            Uri.parse('$rafeeqApiBase/api/auth/login'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"loginMethod": "google", "idToken": idToken}),
          )
          .timeout(const Duration(seconds: 20));
      await _completeAuthFlow(response);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.loginGoogleSignInFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> loginWithFacebook() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
      );
      final token = result.accessToken?.tokenString;
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.loginFacebookCancelled)),
        );
        return;
      }
      final response = await http
          .post(
            Uri.parse('$rafeeqApiBase/api/auth/login'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"loginMethod": "facebook", "accessToken": token}),
          )
          .timeout(const Duration(seconds: 20));
      await _completeAuthFlow(response);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.loginFacebookSignInFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> login() async => loginWithEmail();

  BoxDecoration _marbleFieldDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _LuxuryColors.goldMid.withValues(alpha: 0.95), width: 1.35),
      gradient: LinearGradient(
        begin: const Alignment(-0.85, -1),
        end: const Alignment(0.9, 1.1),
        colors: [
          _LuxuryColors.marble1,
          _LuxuryColors.marble3,
          _LuxuryColors.marble2,
          const Color(0xE6141414),
          _LuxuryColors.marble1,
        ],
        stops: const [0.0, 0.25, 0.48, 0.72, 1.0],
      ),
      boxShadow: [
        BoxShadow(
          color: _LuxuryColors.goldMid.withValues(alpha: 0.12),
          blurRadius: 10,
        ),
      ],
    );
  }

  Widget _brandHeader(double maxWidth) {
    final iconSize = maxWidth < 420 ? 40.0 : 44.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => _LuxuryColors.goldShimmer.createShader(bounds),
          child: Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _LuxuryColors.goldDeep.withValues(alpha: 0.55)),
            ),
            child: Icon(Icons.favorite_rounded, size: iconSize * 0.55, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        _goldGradientText(
          'Rafeeq',
          glow: true,
          style: TextStyle(
            fontSize: maxWidth < 420 ? 28 : 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.35,
          ),
        ),
      ],
    );
  }

  Widget _formCard(BuildContext context, double maxWidth, {bool showBrandHeader = true}) {
    final l10n = context.l10n;
    final titleSize = maxWidth < 420 ? 24.0 : 28.0;
    const goldIcon = _LuxuryColors.goldLight;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth.clamp(280.0, 500.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBrandHeader) ...[
            _brandHeader(maxWidth),
            SizedBox(height: maxWidth < 420 ? 20 : 26),
          ],
          _goldGradientText(
            l10n.loginWelcomeBack,
            textAlign: TextAlign.center,
            glow: true,
            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          _goldGradientText(
            l10n.loginTagline,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, height: 1.35),
          ),
          const SizedBox(height: 22),
          Container(
            decoration: _marbleFieldDecoration(),
            child: TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Color(0xFFEAEAEA)),
              cursorColor: _LuxuryColors.goldMid,
              decoration: InputDecoration(
                hintText: l10n.loginEmail,
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.mail_outline_rounded, color: goldIcon),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: _marbleFieldDecoration(),
            child: TextField(
              controller: passwordController,
              obscureText: _obscure,
              style: const TextStyle(color: Color(0xFFEAEAEA)),
              cursorColor: _LuxuryColors.goldMid,
              decoration: InputDecoration(
                hintText: l10n.loginPassword,
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: goldIcon),
                suffixIcon: IconButton(
                  tooltip: _obscure ? l10n.loginShowPassword : l10n.loginHidePassword,
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: goldIcon,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? true),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                side: const BorderSide(color: _LuxuryColors.goldMid, width: 2),
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return _LuxuryColors.deepTealDark;
                  }
                  return Colors.transparent;
                }),
                checkColor: _LuxuryColors.goldLight,
              ),
              _goldGradientText(
                l10n.loginRememberMe,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.loginForgotPasswordNotImplemented)),
                  );
                },
                child: _goldGradientText(
                  l10n.loginForgotPassword,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: _LuxuryColors.loginGoldGlow,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _LuxuryColors.deepTealDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _LuxuryColors.deepTealDark.withValues(alpha: 0.5),
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _isLoading ? null : loginWithEmail,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 20, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      _isLoading ? l10n.loginSigningIn : l10n.loginSignInWithEmail,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.18))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  l10n.loginOr,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.18))),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: _LuxuryColors.goldMid.withValues(alpha: 0.75)),
                foregroundColor: _LuxuryColors.goldLight,
                backgroundColor: Colors.transparent,
              ),
              onPressed: _isLoading ? null : loginWithGoogle,
              icon: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (b) => _LuxuryColors.goldShimmer.createShader(b),
                child: const Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 28),
              ),
              label: _goldGradientText(l10n.loginSignInWithGoogle, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: _LuxuryColors.goldMid.withValues(alpha: 0.75)),
                foregroundColor: _LuxuryColors.goldLight,
                backgroundColor: Colors.transparent,
              ),
              onPressed: _isLoading ? null : loginWithFacebook,
              icon: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (b) => _LuxuryColors.goldShimmer.createShader(b),
                child: const Icon(Icons.facebook, color: Colors.white, size: 24),
              ),
              label: _goldGradientText(l10n.loginSignInWithFacebook, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.loginDontHaveAccount,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.52), fontSize: 14),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                  );
                },
                child: _goldGradientText(
                  l10n.loginSignUp,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _brandingIllustrationPane(BuildContext context, {required bool showTagline}) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F0),
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.25)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          if (showTagline)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D66).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: Color(0xFF2E7D66)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.loginYourHealth, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                            l10n.loginOurCommitment,
                            style: TextStyle(color: Colors.black.withValues(alpha: 0.55), fontSize: 12.5),
                          ),
                        ],
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

  Widget _loginGlassCard(BuildContext context, RafeeqResponsive r, {required bool showBrandInCard}) {
    final formW = r.authFormMaxWidth.clamp(280.0, 500.0);
    final hPad = r.value(compact: 16.0, medium: 20.0, expanded: 24.0);
    final vPad = r.value(compact: 18.0, medium: 22.0, expanded: 24.0);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.screenGutter,
          vertical: r.value(compact: 12.0, medium: 16.0, expanded: 24.0),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: formW),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _LuxuryColors.glassEmerald,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _LuxuryColors.goldDeep.withValues(alpha: 0.65), width: 1.2),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GeometricPatternPainter(
                          lineColor: Colors.white.withValues(alpha: 0.065),
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                      child: _formCard(context, formW, showBrandHeader: showBrandInCard),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = RafeeqResponsive.of(context);
    final split = r.useSplitAuthLayout;

    final leftPane = _brandingIllustrationPane(context, showTagline: split);
    final loginCard = _loginGlassCard(context, r, showBrandInCard: split);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: rafeeqBackHomeAppBarLeading(
          context,
          onPressed: () => rafeeqNavigateBackToHome(context),
        ),
        actions: const [
          RafeeqLanguageToggle(iconColor: _LuxuryColors.goldLight),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: LoopingAssetVideoBackground(
              assetPath: kHospitalBackgroundVideoAsset,
            ),
          ),
          SafeArea(
            top: false,
            child: RafeeqContentWidth(
              maxWidth: r.pageMaxWidth,
              padding: EdgeInsets.all(r.screenGutter),
              child: split
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 6, child: leftPane),
                        SizedBox(width: r.value(compact: 12.0, medium: 14.0, expanded: 18.0)),
                        Expanded(flex: 5, child: loginCard),
                      ],
                    )
                  : ListView(
                      padding: EdgeInsets.only(top: r.isCompact ? 8 : 12),
                      children: [
                        Center(child: _brandHeader(r.authFormMaxWidth)),
                        SizedBox(height: r.value(compact: 16.0, medium: 20.0, expanded: 24.0)),
                        loginCard,
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
