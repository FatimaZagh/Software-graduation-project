import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'api_config.dart';
import 'l10n/l10n_extensions.dart';
import 'login_screen.dart';
import 'features/auth/presentation/auth_signup_theme.dart';
import 'features/auth/presentation/doctor_signup_screen.dart';
import 'features/auth/presentation/pharmacy_signup_screen.dart';
import 'screens/auth/nurse_signup_screen.dart';
import 'widgets/patient_medical_registration_panel.dart';
import 'widgets/rafeeq_back_home_button.dart';
import 'widgets/responsive_layout.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    this.presetOrgId,
    this.presetOrgName,
    this.lockRoleTo,
  });

  final String? presetOrgId;
  final String? presetOrgName;
  final String? lockRoleTo;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final doctorSpecController = TextEditingController();
  final doctorYearsController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String selectedRole = 'Patient';

  final List<String> roles = [
    'Patient',
    'Doctor',
    'Nurse',
    'Lab Technician',
    'Radiologist',
    'Pharmacist',
    'Intern/Trainee',
    'Staff/Operations',
  ];

  bool _isLoading = false;
  bool _loadingClinics = false;

  String _profileImageBase64 = '';
  File? _selectedProfileImageFile;

  List<dynamic> _clinics = [];
  String? _doctorClinicId;
  String _doctorClinicLabel = '';

  List<dynamic> _orgs = [];
  bool _loadingOrgs = false;
  String? _selectedOrgId;
  String _selectedOrgName = '';

  Future<List<dynamic>>? _liveOrgsFuture;

  final GlobalKey<PatientMedicalRegistrationPanelState> _patientMedicalKey =
      GlobalKey<PatientMedicalRegistrationPanelState>();

  static TextStyle get _fieldTextStyle => AuthSignupTheme.fieldTextStyle();

  Future<List<dynamic>> _fetchOrganizationsLive() async {
    final r = await http
        .get(Uri.parse('$rafeeqApiBase/api/organizations?includePending=true'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  String _doctorSignatureBase64 = '';
  final List<String> _doctorCertificateFilesBase64 = [];

  InputDecoration _inputDecoration(String label, {IconData? prefixIcon, Widget? suffixIcon}) {
    return AuthSignupTheme.inputDecoration(label, prefixIcon: prefixIcon, suffixIcon: suffixIcon);
  }

  TextStyle _sectionTitleStyle() {
    return AuthSignupTheme.sectionTitleStyle(fontSize: 17);
  }

  ButtonStyle _goldOutlineButtonStyle() {
    return AuthSignupTheme.outlineButtonStyle();
  }

  Widget _glassCard({required Widget child}) {
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
              colors: [
                AuthSignupColors.glassTint,
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(color: AuthSignupColors.goldMid.withValues(alpha: 0.92), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _greenInfoCallout() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuthSignupColors.infoPanelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthSignupColors.infoPanelBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AuthSignupColors.infoPanelBorder.withValues(alpha: 0.12),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AuthSignupColors.infoIcon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Opening a new clinic or hospital? Go back to the home page and tap “Register your facility.” This form is only for patients and staff joining an existing facility.',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final lock = widget.lockRoleTo?.trim();
    if (lock != null && lock.isNotEmpty) {
      selectedRole = lock;
    }
    final pid = widget.presetOrgId?.trim();
    if (pid != null && pid.isNotEmpty) {
      _selectedOrgId = pid;
      _selectedOrgName = widget.presetOrgName?.trim() ?? '';
    }
    if (_needsFacilityPicker() && (widget.presetOrgId == null || widget.presetOrgId!.trim().isEmpty)) {
      _liveOrgsFuture = _fetchOrganizationsLive();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (selectedRole == 'Nurse') {
        await _navigateToNurseRegistration();
        return;
      }
      if (selectedRole == 'Doctor') {
        await _navigateToDoctorRegistration();
        return;
      }
      if (selectedRole == 'Pharmacist') {
        await _navigateToPharmacyRegistration();
        return;
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    doctorSpecController.dispose();
    doctorYearsController.dispose();
    super.dispose();
  }

  bool get _useDesktopImagePicker =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _pickImage({
    required void Function(String base64DataUrl) onPicked,
    int maxWidth = 900,
    int imageQuality = 82,
  }) async {
    try {
      if (_useDesktopImagePicker) {
        await _selectDesktopProfileImage(onPicked: onPicked);
        return;
      }

      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        imageQuality: imageQuality,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.isEmpty) return;
      final b64 = base64Encode(bytes);
      onPicked('data:image/jpeg;base64,$b64');
      if (mounted) {
        setState(() => _selectedProfileImageFile = x.path.isNotEmpty ? File(x.path) : null);
      }
    } catch (e, stackTrace) {
      debugPrint('Error choosing profile image: $e\n$stackTrace');
    }
  }

  Future<void> _selectDesktopProfileImage({
    required void Function(String base64DataUrl) onPicked,
  }) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      debugPrint('User cancelled or no file path found.');
      return;
    }

    final picked = result.files.single;
    final path = picked.path;

    if (path == null || path.isEmpty) {
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) {
        debugPrint('User cancelled or no file path found.');
        return;
      }
      final b64 = base64Encode(bytes);
      onPicked('data:image/jpeg;base64,$b64');
      if (mounted) {
        setState(() => _selectedProfileImageFile = null);
      }
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      debugPrint('Selected image file not found: $path');
      return;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      debugPrint('Selected image file is empty.');
      return;
    }

    final b64 = base64Encode(bytes);
    onPicked('data:image/jpeg;base64,$b64');
    if (mounted) {
      setState(() {
        _selectedProfileImageFile = file;
      });
    }
  }

  MemoryImage? _profileMemoryImage() {
    if (_profileImageBase64.isEmpty) return null;
    try {
      final parts = _profileImageBase64.split(',');
      if (parts.length < 2 || parts.last.isEmpty) return null;
      return MemoryImage(base64Decode(parts.last));
    } catch (e) {
      debugPrint('Invalid profile image preview data: $e');
      return null;
    }
  }

  Widget _profilePhotoAvatar({double radius = 28}) {
    if (_selectedProfileImageFile != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AuthSignupColors.marble1,
        child: ClipOval(
          child: Image.file(
            _selectedProfileImageFile!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.person_rounded,
              color: AuthSignupColors.goldLight,
              size: radius,
            ),
          ),
        ),
      );
    }
    final memoryImage = _profileMemoryImage();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AuthSignupColors.marble1,
      backgroundImage: memoryImage,
      child: memoryImage == null
          ? const Icon(Icons.person_rounded, color: AuthSignupColors.goldLight, size: 30)
          : null,
    );
  }

  Future<void> _loadClinicsIfNeeded() async {
    if (selectedRole != 'Doctor') return;
    final orgId = _selectedOrgId;
    if (orgId == null || orgId.isEmpty) return;
    if (_clinics.isNotEmpty || _loadingClinics) return;
    setState(() => _loadingClinics = true);
    try {
      final r = await http
          .get(Uri.parse('$rafeeqApiBase/api/clinics?orgId=$orgId'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception(r.body);
      final list = jsonDecode(r.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _clinics = list;
        _loadingClinics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingClinics = false);
    }
  }

  bool _needsFacilityPicker() => _isStaffRole(selectedRole);

  bool _isStaffRole(String role) {
    return [
      'Doctor',
      'Lab Technician',
      'Radiologist',
      'Pharmacist',
      'Intern/Trainee',
      'Staff/Operations',
    ].contains(role);
  }

  Future<void> _loadOrganizationsIfNeeded() async {
    if (!_isStaffRole(selectedRole)) return;
    if (_orgs.isNotEmpty || _loadingOrgs) return;
    setState(() => _loadingOrgs = true);
    try {
      final r = await http
          .get(Uri.parse('$rafeeqApiBase/api/organizations?includePending=true'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception(r.body);
      final list = jsonDecode(r.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _orgs = list;
        _loadingOrgs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOrgs = false);
    }
  }

  Future<void> _pickOrganization() async {
    await _loadOrganizationsIfNeeded();
    if (!mounted) return;
    final picked = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF152220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final search = TextEditingController();
        List<dynamic> filtered = List<dynamic>.from(_orgs);
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            void apply(String q) {
              final t = q.trim().toLowerCase();
              setSheet(() {
                filtered = t.isEmpty
                    ? List<dynamic>.from(_orgs)
                    : _orgs
                        .where((e) => (e is Map && (e['name']?.toString().toLowerCase().contains(t) ?? false)))
                        .toList();
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select facility',
                            style: GoogleFonts.playfairDisplay(
                              color: AuthSignupColors.goldMid,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: AuthSignupColors.goldLight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: search,
                      style: _fieldTextStyle,
                      cursorColor: AuthSignupColors.goldMid,
                      decoration: _inputDecoration('Search', prefixIcon: Icons.search_rounded),
                      onChanged: apply,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 360,
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No facilities found',
                                style: GoogleFonts.poppins(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final raw = filtered[i];
                                if (raw is! Map) return const SizedBox.shrink();
                                final id = raw['_id']?.toString() ?? '';
                                final name = raw['name']?.toString() ?? '';
                                return Card(
                                  color: AuthSignupColors.marble1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: AuthSignupColors.goldMid, width: 1),
                                  ),
                                  child: ListTile(
                                    leading: const Icon(Icons.local_hospital_outlined, color: AuthSignupColors.goldLight),
                                    title: Text(name, style: _fieldTextStyle),
                                    subtitle: Text(
                                      raw['subscriptionType']?.toString() ?? '',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                                    ),
                                    onTap: () => Navigator.pop(ctx, {'id': id, 'name': name}),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _selectedOrgId = picked['id'];
      _selectedOrgName = picked['name'] ?? '';
      _clinics = [];
      _doctorClinicId = null;
      _doctorClinicLabel = '';
    });
    await _loadClinicsIfNeeded();
  }

  Future<void> _navigateToDoctorRegistration() async {
    await _loadOrganizationsIfNeeded();
    if (!mounted) return;
    final orgId = (_selectedOrgId?.trim().isNotEmpty == true)
        ? _selectedOrgId!.trim()
        : widget.presetOrgId?.trim();
    final orgName = _selectedOrgName.trim().isNotEmpty
        ? _selectedOrgName.trim()
        : widget.presetOrgName?.trim();
    final route = MaterialPageRoute<void>(
      builder: (_) => DoctorSignupScreen(
        presetOrgId: orgId?.isNotEmpty == true ? orgId : null,
        presetOrgName: orgName?.isNotEmpty == true ? orgName : null,
        presetClinicId: _doctorClinicId,
      ),
    );
    final lockedDoctor = widget.lockRoleTo?.trim() == 'Doctor';
    if (lockedDoctor) {
      await Navigator.pushReplacement(context, route);
    } else {
      await Navigator.push<void>(context, route);
      if (!mounted) return;
      setState(() => selectedRole = 'Patient');
    }
  }

  Future<void> _navigateToPharmacyRegistration() async {
    await _loadOrganizationsIfNeeded();
    if (!mounted) return;
    final orgId = (_selectedOrgId?.trim().isNotEmpty == true)
        ? _selectedOrgId!.trim()
        : widget.presetOrgId?.trim();
    final orgName = _selectedOrgName.trim().isNotEmpty
        ? _selectedOrgName.trim()
        : widget.presetOrgName?.trim();
    final route = MaterialPageRoute<void>(
      builder: (_) => PharmacySignupScreen(
        presetOrgId: orgId?.isNotEmpty == true ? orgId : null,
        presetOrgName: orgName?.isNotEmpty == true ? orgName : null,
      ),
    );
    final locked = widget.lockRoleTo?.trim() == 'Pharmacist';
    if (locked) {
      await Navigator.pushReplacement(context, route);
    } else {
      await Navigator.push<void>(context, route);
      if (!mounted) return;
      setState(() => selectedRole = 'Patient');
    }
  }

  Future<void> _navigateToNurseRegistration() async {
    await _loadOrganizationsIfNeeded();
    if (!mounted) return;
    final orgId = (_selectedOrgId?.trim().isNotEmpty == true)
        ? _selectedOrgId!.trim()
        : widget.presetOrgId?.trim();
    final orgName = _selectedOrgName.trim().isNotEmpty
        ? _selectedOrgName.trim()
        : widget.presetOrgName?.trim();
    final route = MaterialPageRoute<void>(
      builder: (_) => NurseSignupScreen(
        presetOrgId: orgId?.isNotEmpty == true ? orgId : null,
        presetOrgName: orgName?.isNotEmpty == true ? orgName : null,
      ),
    );
    final lockedNurse = widget.lockRoleTo?.trim() == 'Nurse';
    if (lockedNurse) {
      await Navigator.pushReplacement(context, route);
    } else {
      await Navigator.push<void>(context, route);
      if (!mounted) return;
      setState(() => selectedRole = 'Patient');
    }
  }

  Future<void> signup() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      await _loadClinicsIfNeeded();
      if (_isStaffRole(selectedRole)) {
        if (_selectedOrgId == null || _selectedOrgId!.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.authSelectFacilityFirst)),
          );
          return;
        }
      }

      if (selectedRole == 'Patient') {
        final pv = _patientMedicalKey.currentState?.validateForSubmit();
        if (pv != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pv)));
          return;
        }
        final medical = _patientMedicalKey.currentState!.buildMedicalRegistrationMap();
        final body = <String, dynamic>{
          'loginMethod': 'email',
          'fullName': nameController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text,
          'confirmPassword': confirmPasswordController.text,
          'profileImageUrl': _profileImageBase64,
          if (_selectedOrgId != null && _selectedOrgId!.trim().isNotEmpty) 'orgId': _selectedOrgId,
          ...medical,
        };
        final response = await http
            .post(
              Uri.parse('$rafeeqApiBase/api/auth/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 90));

        if (response.statusCode == 201) {
          if (!mounted) return;
          String msg = 'Account created successfully!';
          try {
            final data = jsonDecode(response.body);
            if (data is Map && data['message'] is String) msg = data['message'] as String;
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.body}')),
          );
        }
        return;
      }

      final response = await http
          .post(
            Uri.parse('$rafeeqApiBase/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (_isStaffRole(selectedRole)) 'orgId': _selectedOrgId,
              'name': nameController.text,
              'email': emailController.text,
              'password': passwordController.text,
              'role': selectedRole,
              'profileImageUrl': _profileImageBase64,
              if (selectedRole == 'Doctor') ...{
                'doctorClinicId': _doctorClinicId,
                'doctorSpecialization': doctorSpecController.text.trim(),
                'doctorYearsExperience': doctorYearsController.text.trim(),
                'doctorCertificatesBase64': _doctorCertificateFilesBase64,
                'doctorSignatureBase64': _doctorSignatureBase64,
              }
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (!mounted) return;
        String msg = 'Account created successfully!';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] is String) msg = data['message'] as String;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final r = RafeeqResponsive.of(context);
    final titleSize = r.scaleFont(r.value(compact: 20.0, medium: 22.0, expanded: 24.0));
    final subtitleSize = r.scaleFont(13);

    final isPatientFlow = widget.lockRoleTo?.trim() == 'Patient';
    final appBarTitle = isPatientFlow ? 'Patient Registration' : 'Sign Up';
    final formTitle = isPatientFlow ? 'Create your patient account' : 'Create account';
    final formSubtitle = isPatientFlow
        ? 'Register to book appointments and manage your health with Rafeeq'
        : 'Join an existing facility on Rafeeq';

    return Scaffold(
      backgroundColor: AuthSignupColors.scaffoldBlack,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AuthSignupTheme.authAppBar(
        context: context,
        title: appBarTitle,
        automaticallyImplyLeading: false,
        leading: rafeeqBackHomeAppBarLeading(context),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: AuthSignupTheme.gradientBackgroundDecoration()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    r.horizontalPadding,
                    8,
                    r.horizontalPadding,
                    24 + bottomInset,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: r.authFormMaxWidth),
                      child: _glassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formTitle,
                              textAlign: TextAlign.center,
                              style: AuthSignupTheme.sectionTitleStyle(fontSize: titleSize),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formSubtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.urbanist(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: subtitleSize,
                                height: 1.35,
                              ),
                            ),
                              const SizedBox(height: 18),
                              _greenInfoCallout(),
                              const SizedBox(height: 18),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AuthSignupColors.goldMid, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AuthSignupColors.goldMid.withValues(alpha: 0.25),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: _profilePhotoAvatar(),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Profile photo',
                                          style: GoogleFonts.poppins(
                                            color: AuthSignupColors.goldMid,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Upload during registration',
                                          style: GoogleFonts.poppins(
                                            color: AuthSignupColors.goldLight.withValues(alpha: 0.75),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    style: _goldOutlineButtonStyle(),
                                    onPressed: () => _pickImage(onPicked: (v) => setState(() => _profileImageBase64 = v)),
                                    icon: const Icon(Icons.upload_rounded, size: 20, color: AuthSignupColors.goldLight),
                                    label: Text(
                                      'Upload',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: AuthSignupColors.goldLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: nameController,
                                style: _fieldTextStyle,
                                cursorColor: AuthSignupColors.goldMid,
                                decoration: _inputDecoration('Full Name', prefixIcon: Icons.badge_outlined),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: _fieldTextStyle,
                                cursorColor: AuthSignupColors.goldMid,
                                decoration: _inputDecoration('Email', prefixIcon: Icons.mail_outline_rounded),
                              ),
                              const SizedBox(height: 14),
                              if (widget.lockRoleTo != null &&
                                  widget.lockRoleTo!.trim().isNotEmpty &&
                                  widget.lockRoleTo!.trim() != 'Patient')
                                InputDecorator(
                                  decoration: _inputDecoration('Register as', prefixIcon: Icons.verified_user_outlined),
                                  child: Text(
                                    selectedRole,
                                    style: _fieldTextStyle.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                )
                              else
                                DropdownButtonFormField<String>(
                                  key: ValueKey(selectedRole),
                                  initialValue: selectedRole,
                                  dropdownColor: AuthSignupTheme.dropdownSurfaceColor(),
                                  style: _fieldTextStyle,
                                  iconEnabledColor: AuthSignupColors.goldMid,
                                  decoration: _inputDecoration('Register As', prefixIcon: Icons.work_outline_rounded),
                                  items: roles
                                      .map(
                                        (role) => DropdownMenuItem(
                                          value: role,
                                          child: Text(role, style: _fieldTextStyle),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (String? newValue) async {
                                    if (newValue == null) return;
                                    if (newValue == 'Nurse') {
                                      await _navigateToNurseRegistration();
                                      return;
                                    }
                                    if (newValue == 'Doctor') {
                                      await _navigateToDoctorRegistration();
                                      return;
                                    }
                                    if (newValue == 'Pharmacist') {
                                      await _navigateToPharmacyRegistration();
                                      return;
                                    }
                                    setState(() {
                                      selectedRole = newValue;
                                      if (!_isStaffRole(selectedRole)) {
                                        _selectedOrgId = null;
                                        _selectedOrgName = '';
                                        _liveOrgsFuture = null;
                                      } else if (widget.presetOrgId == null || widget.presetOrgId!.trim().isEmpty) {
                                        _liveOrgsFuture = _fetchOrganizationsLive();
                                      }
                                      _clinics = [];
                                      _doctorClinicId = null;
                                      _doctorClinicLabel = '';
                                    });
                                    await _loadOrganizationsIfNeeded();
                                    await _loadClinicsIfNeeded();
                                  },
                                ),
                              const SizedBox(height: 14),
                              if (_isStaffRole(selectedRole)) ...[
                                if (widget.presetOrgId != null && widget.presetOrgId!.trim().isNotEmpty)
                                  InputDecorator(
                                    decoration: _inputDecoration('Facility', prefixIcon: Icons.apartment_rounded),
                                    child: Text(
                                      _selectedOrgName.isEmpty ? widget.presetOrgId!.trim() : _selectedOrgName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: _fieldTextStyle.copyWith(fontWeight: FontWeight.w500),
                                    ),
                                  )
                                else
                                  FutureBuilder<List<dynamic>>(
                                    future: _liveOrgsFuture,
                                    builder: (context, snap) {
                                      final busy = snap.connectionState == ConnectionState.waiting;
                                      if (snap.hasError) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            OutlinedButton.icon(
                                              style: _goldOutlineButtonStyle(),
                                              onPressed: _pickOrganization,
                                              icon: const Icon(Icons.apartment_rounded, color: AuthSignupColors.goldLight),
                                              label: Text(
                                                'Select facility (tap to retry)',
                                                style: GoogleFonts.poppins(color: AuthSignupColors.goldLight),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Facility directory failed to load.',
                                              style: GoogleFonts.poppins(
                                                color: Colors.red.shade200,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      final list = snap.data ?? const [];
                                      _orgs = list;
                                      return SizedBox(
                                        height: 52,
                                        child: OutlinedButton.icon(
                                          style: _goldOutlineButtonStyle(),
                                          onPressed: busy ? null : _pickOrganization,
                                          icon: const Icon(Icons.apartment_rounded, color: AuthSignupColors.goldLight),
                                          label: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _selectedOrgId == null || _selectedOrgId!.isEmpty
                                                  ? (busy ? 'Loading facilities…' : 'Select facility')
                                                  : 'Facility: ${_selectedOrgName.isEmpty ? _selectedOrgId! : _selectedOrgName}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                color: AuthSignupColors.goldLight,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                const SizedBox(height: 14),
                              ],
                              TextField(
                                controller: passwordController,
                                obscureText: true,
                                style: _fieldTextStyle,
                                cursorColor: AuthSignupColors.goldMid,
                                decoration: _inputDecoration('Password', prefixIcon: Icons.lock_outline_rounded),
                              ),
                              if (selectedRole == 'Patient') ...[
                                const SizedBox(height: 14),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Medical profile',
                                    style: _sectionTitleStyle(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                PatientMedicalRegistrationPanel(
                                  key: _patientMedicalKey,
                                  passwordController: passwordController,
                                  confirmPasswordController: confirmPasswordController,
                                ),
                              ],
                              if (selectedRole == 'Doctor') ...[
                                const SizedBox(height: 18),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(context.l10n.authDoctorDetails, style: _sectionTitleStyle()),
                                ),
                                const SizedBox(height: 10),
                                if (_loadingClinics)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: LinearProgressIndicator(
                                      color: AuthSignupColors.goldMid,
                                      backgroundColor: Color(0x33FFFFFF),
                                    ),
                                  ),
                                DropdownButtonFormField<String>(
                                  key: ValueKey(_doctorClinicId ?? 'none'),
                                  initialValue: _doctorClinicId,
                                  dropdownColor: AuthSignupTheme.dropdownSurfaceColor(),
                                  style: _fieldTextStyle,
                                  iconEnabledColor: AuthSignupColors.goldMid,
                                  decoration: _inputDecoration('Clinic', prefixIcon: Icons.local_hospital_outlined),
                                  items: [
                                    for (final raw in _clinics)
                                      if (raw is Map && raw['_id'] != null)
                                        DropdownMenuItem<String>(
                                          value: raw['_id'].toString(),
                                          child: Text(
                                            raw['name']?.toString() ?? 'Clinic',
                                            style: _fieldTextStyle,
                                          ),
                                        ),
                                  ],
                                  onChanged: (v) {
                                    var label = '';
                                    for (final raw in _clinics) {
                                      if (raw is Map && raw['_id']?.toString() == v) {
                                        label = raw['name']?.toString() ?? '';
                                        break;
                                      }
                                    }
                                    setState(() {
                                      _doctorClinicId = v;
                                      _doctorClinicLabel = label;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: doctorSpecController,
                                  style: _fieldTextStyle,
                                  cursorColor: AuthSignupColors.goldMid,
                                  decoration: _inputDecoration(
                                    'Specialization',
                                    prefixIcon: Icons.medical_services_outlined,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: doctorYearsController,
                                  keyboardType: TextInputType.number,
                                  style: _fieldTextStyle,
                                  cursorColor: AuthSignupColors.goldMid,
                                  decoration: _inputDecoration(
                                    'Years of experience',
                                    prefixIcon: Icons.timeline_outlined,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  style: _goldOutlineButtonStyle(),
                                  onPressed: () => _pickImage(
                                    onPicked: (v) => _doctorSignatureBase64 = v,
                                    maxWidth: 700,
                                    imageQuality: 75,
                                  ),
                                  icon: const Icon(Icons.draw_rounded, color: AuthSignupColors.goldLight),
                                  label: Text(
                                    _doctorSignatureBase64.isEmpty ? 'Upload signature' : 'Signature added',
                                    style: GoogleFonts.poppins(color: AuthSignupColors.goldLight),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  style: _goldOutlineButtonStyle(),
                                  onPressed: () => _pickImage(
                                    onPicked: (v) => _doctorCertificateFilesBase64.add(v),
                                    maxWidth: 1100,
                                    imageQuality: 80,
                                  ),
                                  icon: const Icon(Icons.file_present_rounded, color: AuthSignupColors.goldLight),
                                  label: Text(
                                    _doctorCertificateFilesBase64.isEmpty
                                        ? 'Upload certificates'
                                        : 'Certificates (${_doctorCertificateFilesBase64.length})',
                                    style: GoogleFonts.poppins(color: AuthSignupColors.goldLight),
                                  ),
                                ),
                                if (_doctorClinicLabel.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Selected clinic: $_doctorClinicLabel',
                                      style: GoogleFonts.poppins(
                                        color: AuthSignupColors.goldLight.withValues(alpha: 0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 22),
                              AuthSignupTheme.primaryButton(
                                label: _isLoading ? 'Loading…' : 'Sign Up',
                                onPressed: signup,
                                loading: _isLoading,
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                                  );
                                },
                                child: Text(
                                  'Already have an account? Sign In',
                                  style: GoogleFonts.poppins(
                                    color: AuthSignupColors.goldLight,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AuthSignupColors.goldMid,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
