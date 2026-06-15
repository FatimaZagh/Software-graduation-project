import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../api_config.dart';
import '../../../core/rafeeq_regional_defaults.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../tenant_state.dart';
import '../data/clinical_signup_clinics_api.dart';
import 'auth_signup_theme.dart';

const _genders = ['Male', 'Female'];
const _employmentTypes = ['Full-time', 'Part-time'];

const _educationQualificationOptions = <({String value, String label})>[
  (value: 'Diploma', label: 'Diploma (دبلوم)'),
  (value: "Bachelor's Degree", label: "Bachelor's Degree (بكالوريوس)"),
  (value: "Master's Degree", label: "Master's Degree (ماجستير)"),
  (value: 'Ph.D.', label: 'Ph.D. (دكتوراه)'),
];

enum ClinicalSignupVariant { labTechnician, radiologyTechnologist }

class _ClinicalSignupConfig {
  const _ClinicalSignupConfig({
    required this.variant,
    required this.appBarTitle,
    required this.headline,
    required this.apiRole,
    required this.specialtyDepartment,
    required this.showLicenseExpiry,
  });

  final ClinicalSignupVariant variant;
  final String appBarTitle;
  final String headline;
  final String apiRole;
  final String specialtyDepartment;
  final bool showLicenseExpiry;

  static _ClinicalSignupConfig of(ClinicalSignupVariant variant) {
    switch (variant) {
      case ClinicalSignupVariant.labTechnician:
        return const _ClinicalSignupConfig(
          variant: ClinicalSignupVariant.labTechnician,
          appBarTitle: 'Laboratory Technician',
          headline: 'Laboratory technician registration',
          apiRole: 'Lab Technician',
          specialtyDepartment: 'Laboratory',
          showLicenseExpiry: false,
        );
      case ClinicalSignupVariant.radiologyTechnologist:
        return const _ClinicalSignupConfig(
          variant: ClinicalSignupVariant.radiologyTechnologist,
          appBarTitle: 'Radiology Technologist',
          headline: 'Radiology technologist registration',
          apiRole: 'Radiologist',
          specialtyDepartment: 'Radiology',
          showLicenseExpiry: true,
        );
    }
  }
}

/// Premium dark registration for laboratory and radiology technologists.
class ClinicalTechnologistSignupScreen extends StatefulWidget {
  const ClinicalTechnologistSignupScreen({
    super.key,
    required this.variant,
    this.presetOrgId,
    this.presetOrgName,
  });

  final ClinicalSignupVariant variant;
  final String? presetOrgId;
  final String? presetOrgName;

  @override
  State<ClinicalTechnologistSignupScreen> createState() => _ClinicalTechnologistSignupScreenState();
}

class LabTechnicianSignupScreen extends StatelessWidget {
  const LabTechnicianSignupScreen({super.key, this.presetOrgId, this.presetOrgName});

  final String? presetOrgId;
  final String? presetOrgName;

  @override
  Widget build(BuildContext context) {
    return ClinicalTechnologistSignupScreen(
      variant: ClinicalSignupVariant.labTechnician,
      presetOrgId: presetOrgId,
      presetOrgName: presetOrgName,
    );
  }
}

class RadiologyTechnologistSignupScreen extends StatelessWidget {
  const RadiologyTechnologistSignupScreen({super.key, this.presetOrgId, this.presetOrgName});

  final String? presetOrgId;
  final String? presetOrgName;

  @override
  Widget build(BuildContext context) {
    return ClinicalTechnologistSignupScreen(
      variant: ClinicalSignupVariant.radiologyTechnologist,
      presetOrgId: presetOrgId,
      presetOrgName: presetOrgName,
    );
  }
}

class _ClinicalTechnologistSignupScreenState extends State<ClinicalTechnologistSignupScreen> {
  late final _ClinicalSignupConfig _config = _ClinicalSignupConfig.of(widget.variant);

  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  bool _submitting = false;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _nationalId = TextEditingController();
  final _nationality = TextEditingController();
  bool _nationalitySeeded = false;
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _experienceYears = TextEditingController(text: '0');
  final _licenseNumber = TextEditingController();
  final _institution = TextEditingController();

  String _gender = 'Male';
  String _employmentType = 'Full-time';
  String _educationQualification = 'Diploma';
  DateTime? _birthDate;
  DateTime? _licenseExpiry;
  String _profileBase64 = '';

  String? _idCopyData;
  String? _licenseDocData;
  String? _degreeCertData;
  String? _additionalCertsData;
  String? _certificationsData;
  String? _cvData;
  String _idCopyLabel = '';
  String _licenseDocLabel = '';
  String _degreeCertLabel = '';
  String _additionalCertsLabel = '';
  String _certificationsLabel = '';
  String _cvLabel = '';

  String? _orgId;
  String _orgName = '';
  String? _clinicId;
  String _clinicName = '';
  List<dynamic> _orgs = [];
  List<dynamic> _clinics = [];
  bool _clinicsLoading = false;

  static final _emailRegex = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[\w\.\-]+$');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nationalitySeeded) {
      _nationality.text = context.isArabicLocale
          ? RafeeqRegionalDefaults.nationalityArabic
          : RafeeqRegionalDefaults.nationalityEnglish;
      _nationalitySeeded = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _orgId = widget.presetOrgId;
    _orgName = widget.presetOrgName ?? '';
    _loadOrgs();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _nationalId.dispose();
    _nationality.dispose();
    _phone.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _experienceYears.dispose();
    _licenseNumber.dispose();
    _institution.dispose();
    super.dispose();
  }

  Future<void> _loadOrgs() async {
    try {
      final r = await http
          .get(Uri.parse('$rafeeqApiBase/api/organizations?includePending=true'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200 && mounted) {
        final list = jsonDecode(r.body) as List<dynamic>;
        setState(() {
          _orgs = list;
          if ((_orgId == null || _orgId!.isEmpty) && TenantState.instance.orgId.isNotEmpty) {
            _orgId = TenantState.instance.orgId;
          }
          if (_orgId != null && _orgName.isEmpty) {
            final match = list.cast<Map>().where((o) => o['_id']?.toString() == _orgId);
            if (match.isNotEmpty) _orgName = match.first['name']?.toString() ?? '';
          }
        });
        await _loadClinics();
      }
    } catch (_) {}
  }

  Future<void> _loadClinics() async {
    final oid = _orgId;
    if (oid == null || oid.isEmpty) {
      if (mounted) {
        setState(() {
          _clinics = [];
          _clinicId = null;
          _clinicName = '';
          _clinicsLoading = false;
        });
      }
      return;
    }

    setState(() => _clinicsLoading = true);
    try {
      final r = await http.get(Uri.parse('$rafeeqApiBase/api/clinics?orgId=$oid')).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200 && mounted) {
        final list = jsonDecode(r.body) as List<dynamic>;
        final allMaps = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        final filtered = _config.variant == ClinicalSignupVariant.labTechnician
            ? ClinicalSignupClinicsApi.filterForLabTechnician(allMaps)
            : ClinicalSignupClinicsApi.filterForRadiologyTechnologist(allMaps);
        final display = filtered.isNotEmpty ? filtered : allMaps;
        if (kDebugMode) {
          // ignore: avoid_print
          print('Clinics fetched: ${display.length}');
        }
        setState(() {
          _clinics = display;
          _clinicsLoading = false;
          if (_clinicId == null && display.length == 1) {
            _clinicId = display.first['_id']?.toString();
            _clinicName = display.first['name']?.toString() ?? '';
          }
          if (_clinicId != null && !display.any((c) => c['_id']?.toString() == _clinicId)) {
            _clinicId = null;
            _clinicName = '';
          }
        });
      } else if (mounted) {
        setState(() {
          _clinics = [];
          _clinicsLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Clinics fetch error: $e');
      }
      if (mounted) {
        setState(() {
          _clinics = [];
          _clinicId = null;
          _clinicName = '';
          _clinicsLoading = false;
        });
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 88);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() => _profileBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  Future<void> _pickDocument(
    void Function(String data, String name) onDone, {
    List<String>? allowedExtensions,
  }) async {
    final r = await FilePicker.platform.pickFiles(
      withData: true,
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final ext = (f.extension ?? 'bin').toLowerCase();
    final mime = ext == 'pdf'
        ? 'application/pdf'
        : (ext == 'png' ? 'image/png' : 'image/jpeg');
    onDone('data:$mime;base64,${base64Encode(bytes)}', f.name);
    if (mounted) setState(() {});
  }

  String _educationLevelApi(String qualification) {
    switch (qualification) {
      case "Bachelor's Degree":
        return 'BSc';
      case "Master's Degree":
      case 'Ph.D.':
        return 'MSc';
      default:
        return 'Diploma';
    }
  }

  Future<void> _pickDate({
    required bool isBirthDate,
    required void Function(DateTime) onPicked,
  }) async {
    final initial = isBirthDate
        ? (_birthDate ?? DateTime(1995))
        : (_licenseExpiry ?? DateTime.now().add(const Duration(days: 365)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isBirthDate ? DateTime(1950) : DateTime.now(),
      lastDate: isBirthDate ? DateTime.now() : DateTime.now().add(const Duration(days: 3650)),
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
    if (picked != null) onPicked(picked);
  }

  String _employmentApiValue(String display) {
    switch (display) {
      case 'Part-time':
        return 'Part-Time';
      default:
        return 'Full-Time';
    }
  }

  String? _resolvedOrgId() => _orgId?.trim().isNotEmpty == true ? _orgId!.trim() : null;

  Widget _buildFacilityDropdown(TextStyle fieldStyle) {
    if (_orgs.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      value: _orgId,
      dropdownColor: const Color(0xFF1A1A18),
      style: fieldStyle,
      decoration: AuthSignupTheme.inputDecoration('Facility / Hospital'),
      items: _orgs.map((o) {
        final m = o as Map;
        final id = m['_id']?.toString() ?? '';
        return DropdownMenuItem(value: id, child: Text(m['name']?.toString() ?? id, style: fieldStyle));
      }).toList(),
      onChanged: (v) async {
        final match = _orgs.whereType<Map>().where((o) => o['_id']?.toString() == v);
        setState(() {
          _orgId = v;
          _orgName = match.isNotEmpty ? match.first['name']?.toString() ?? '' : '';
          _clinicId = null;
          _clinicName = '';
        });
        await _loadClinics();
      },
      validator: (v) => v == null || v.isEmpty ? 'Please select a facility' : null,
    );
  }

  Widget _buildClinicDropdown(TextStyle fieldStyle) {
    if (_orgId == null || _orgId!.isEmpty) {
      return InputDecorator(
        decoration: AuthSignupTheme.inputDecoration('Clinic / hospital name'),
        child: Text(
          'Select a facility first',
          style: fieldStyle.copyWith(color: Colors.white.withValues(alpha: 0.38)),
        ),
      );
    }

    if (_clinicsLoading) {
      return InputDecorator(
        decoration: AuthSignupTheme.inputDecoration(
          'Clinic / hospital name',
          suffixIcon: const SizedBox(
            width: 22,
            height: 22,
            child: Padding(
              padding: EdgeInsets.all(2),
              child: CircularProgressIndicator(strokeWidth: 2, color: AuthSignupColors.gold),
            ),
          ),
        ),
        child: Text(
          'Loading clinics…',
          style: fieldStyle.copyWith(color: Colors.white.withValues(alpha: 0.54)),
        ),
      );
    }

    if (_clinics.isEmpty) {
      return InputDecorator(
        decoration: AuthSignupTheme.inputDecoration('Clinic / hospital name'),
        child: Text(
          'No available clinics found',
          style: fieldStyle.copyWith(color: Colors.white.withValues(alpha: 0.54)),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _clinicId,
      dropdownColor: const Color(0xFF1A1A18),
      style: fieldStyle,
      decoration: AuthSignupTheme.inputDecoration('Clinic / hospital name'),
      items: _clinics.map((c) {
        final m = c as Map;
        final id = m['_id']?.toString() ?? '';
        return DropdownMenuItem(value: id, child: Text(m['name']?.toString() ?? id, style: fieldStyle));
      }).toList(),
      onChanged: (v) {
        final match = _clinics.cast<Map>().where((c) => c['_id']?.toString() == v);
        setState(() {
          _clinicId = v;
          _clinicName = match.isNotEmpty ? match.first['name']?.toString() ?? '' : '';
        });
      },
      validator: (v) {
        if (_clinicsLoading) return null;
        if (_clinics.isEmpty) return 'No available clinics found';
        if (v == null || v.isEmpty) return 'Please select your clinic';
        return null;
      },
    );
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
            Text(title, style: AuthSignupTheme.sectionTitleStyle(fontSize: 18)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _fieldSpacer() => const SizedBox(height: 12);

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final display = value == null ? 'Select date' : '${value.toLocal()}'.split(' ').first;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: AuthSignupTheme.inputDecoration(label, prefixIcon: Icons.calendar_month_outlined),
        child: Text(
          display,
          style: AuthSignupTheme.fieldTextStyle().copyWith(
            color: value == null ? Colors.white.withValues(alpha: 0.45) : const Color(0xFFF5F5F0),
          ),
        ),
      ),
    );
  }

  Widget _uploadButton({
    required String label,
    required String statusLabel,
    required VoidCallback onPick,
  }) {
    final done = statusLabel.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        style: AuthSignupTheme.outlineButtonStyle().copyWith(
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 14, horizontal: 12)),
        ),
        onPressed: onPick,
        icon: Icon(
          done ? Icons.check_circle_outline : Icons.upload_file,
          color: done ? AuthSignupColors.gold : Colors.white54,
        ),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.urbanist(fontWeight: FontWeight.w600)),
              if (done)
                Text(
                  statusLabel,
                  style: GoogleFonts.urbanist(fontSize: 11, color: AuthSignupColors.gold.withValues(alpha: 0.85)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profilePhotoRow() {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AuthSignupColors.fieldFill,
          backgroundImage: _profileBase64.isNotEmpty
              ? MemoryImage(base64Decode(_profileBase64.split(',').last))
              : null,
          child: _profileBase64.isEmpty
              ? const Icon(Icons.person_outline, color: AuthSignupColors.goldLight, size: 40)
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: OutlinedButton.icon(
            style: AuthSignupTheme.outlineButtonStyle(),
            onPressed: _pickProfilePhoto,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Upload profile photo'),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final orgId = _resolvedOrgId();
    if (orgId == null || orgId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your facility / organization')),
      );
      return;
    }

    if (_config.showLicenseExpiry && _licenseExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Professional license expiry date is required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final educationLevel = _educationLevelApi(_educationQualification);

      final body = <String, dynamic>{
        'orgId': orgId,
        'targetOrgId': orgId,
        'role': _config.apiRole,
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'profileImage': _profileBase64,
        'gender': _gender,
        'nationality': _nationality.text.trim(),
        'employeeId': _nationalId.text.trim(),
        'specialtyOrDepartment': _config.specialtyDepartment,
        'experienceYears': int.tryParse(_experienceYears.text.trim()) ?? 0,
        'educationLevel': educationLevel,
        'university': _institution.text.trim(),
        'qualifications': _educationQualification,
        'certifications': _certificationsLabel,
        if (_certificationsData != null) 'certificationsFile': _certificationsData,
        'licenseNumber': _licenseNumber.text.trim(),
        'employmentType': _employmentApiValue(_employmentType),
        'currentClinic': _clinicName.isNotEmpty ? _clinicName : _orgName,
        if (_clinicId != null) 'clinicId': _clinicId,
        if (_clinicId != null) 'branchId': _clinicId,
        if (_birthDate != null) 'birthDate': _birthDate!.toIso8601String(),
        if (_licenseExpiry != null) 'licenseExpiryDate': _licenseExpiry!.toIso8601String(),
        'documents': {
          'idCardUrl': _idCopyData ?? '',
          'professionalLicenseUrl': _licenseDocData ?? '',
          'degreeCertificateUrl': _degreeCertData ?? '',
          'additionalCertificationsUrl': _additionalCertsData ?? '',
          'certificationsUrl': _certificationsData ?? '',
          'cvUrl': _cvData ?? '',
        },
      };

      final r = await http
          .post(
            Uri.parse('$rafeeqApiBase/api/auth/register/staff'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));

      if (!mounted) return;
      if (r.statusCode == 201) {
        await _showSuccessDialog();
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.body)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AuthSignupColors.glassCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AuthSignupColors.gold, width: 1.8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: AuthSignupColors.gold, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    'Registration submitted',
                    style: GoogleFonts.urbanist(color: AuthSignupColors.gold, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your registration profile has been recorded successfully. Your account is currently pending approval from the clinic administrator.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(color: Colors.white.withValues(alpha: 0.9), height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    style: AuthSignupTheme.primaryButtonStyle().copyWith(minimumSize: const WidgetStatePropertyAll(Size(160, 44))),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('OK', style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _localizedAppBarTitle(S l10n) => switch (widget.variant) {
        ClinicalSignupVariant.labTechnician => l10n.authRoleLabTech,
        ClinicalSignupVariant.radiologyTechnologist => l10n.authRoleRadiology,
      };

  String _localizedHeadline(S l10n) => switch (widget.variant) {
        ClinicalSignupVariant.labTechnician => l10n.authLabTechRegistration,
        ClinicalSignupVariant.radiologyTechnologist => l10n.authRadiologyRegistration,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fieldStyle = AuthSignupTheme.fieldTextStyle();

    return AuthSignupTheme.darkGradientScaffold(
      context: context,
      appBarTitle: _localizedAppBarTitle(l10n),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Scrollbar(
              controller: _scroll,
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    _localizedHeadline(l10n),
                    textAlign: TextAlign.center,
                    style: AuthSignupTheme.screenTitleStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.authSignupPendingApproval,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  _buildFacilityDropdown(fieldStyle),
                  const SizedBox(height: 12),
                  _section('Personal information', [
                    _profilePhotoRow(),
                    _fieldSpacer(),
                    TextFormField(
                      controller: _firstName,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('First name', prefixIcon: Icons.badge_outlined),
                      validator: (v) => v == null || v.trim().isEmpty ? 'First name is required' : null,
                    ),
                    _fieldSpacer(),
                    TextFormField(
                      controller: _lastName,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Last name', prefixIcon: Icons.badge_outlined),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Last name is required' : null,
                    ),
                    _fieldSpacer(),
                    _dateField(
                      label: 'Date of birth',
                      value: _birthDate,
                      onTap: () => _pickDate(
                        isBirthDate: true,
                        onPicked: (d) => setState(() => _birthDate = d),
                      ),
                    ),
                    _fieldSpacer(),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      dropdownColor: AuthSignupTheme.dropdownSurfaceColor(),
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Gender', prefixIcon: Icons.wc_outlined),
                      items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g, style: fieldStyle))).toList(),
                      onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                    ),
                    _fieldSpacer(),
                    TextFormField(
                      controller: _nationalId,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('National ID / Passport number', prefixIcon: Icons.credit_card_outlined),
                      validator: (v) => v == null || v.trim().isEmpty ? 'ID / passport number is required' : null,
                    ),
                    _fieldSpacer(),
                    TextFormField(
                      controller: _nationality,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Nationality', prefixIcon: Icons.flag_outlined),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Nationality is required' : null,
                    ),
                    _fieldSpacer(),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Phone number', prefixIcon: Icons.phone_outlined),
                      validator: (v) => v == null || v.trim().length < 8 ? 'Enter a valid phone number' : null,
                    ),
                    _fieldSpacer(),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Email address', prefixIcon: Icons.email_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!_emailRegex.hasMatch(v.trim())) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                  ]),
                  _section('Account information', [
                    TextFormField(
                      controller: _username,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Username', prefixIcon: Icons.alternate_email),
                      validator: (v) => v == null || v.trim().length < 3 ? 'Username must be at least 3 characters' : null,
                    ),
                    _fieldSpacer(),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Password', prefixIcon: Icons.lock_outline),
                      validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                    ),
                    _fieldSpacer(),
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: true,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Confirm password', prefixIcon: Icons.lock_reset),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirm your password';
                        if (v != _password.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ]),
                  _section('Employment information', [
                    _buildClinicDropdown(fieldStyle),
                    _fieldSpacer(),
                    DropdownButtonFormField<String>(
                      value: _employmentType,
                      dropdownColor: AuthSignupTheme.dropdownSurfaceColor(),
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Employment type', prefixIcon: Icons.schedule_outlined),
                      items: _employmentTypes
                          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: fieldStyle)))
                          .toList(),
                      onChanged: (v) => setState(() => _employmentType = v ?? 'Full-time'),
                    ),
                    _fieldSpacer(),
                    TextFormField(
                      controller: _experienceYears,
                      keyboardType: TextInputType.number,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Years of experience', prefixIcon: Icons.timeline_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Years of experience is required';
                        if (int.tryParse(v.trim()) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                  ]),
                  _section('Professional information', [
                    TextFormField(
                      controller: _licenseNumber,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Professional license number', prefixIcon: Icons.verified_outlined),
                      validator: (v) => v == null || v.trim().isEmpty ? 'License number is required' : null,
                    ),
                    if (_config.showLicenseExpiry) ...[
                      _fieldSpacer(),
                      _dateField(
                        label: 'License expiry date',
                        value: _licenseExpiry,
                        onTap: () => _pickDate(
                          isBirthDate: false,
                          onPicked: (d) => setState(() => _licenseExpiry = d),
                        ),
                      ),
                    ],
                    _fieldSpacer(),
                    DropdownButtonFormField<String>(
                      value: _educationQualification,
                      dropdownColor: AuthSignupTheme.dropdownSurfaceColor(),
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Educational qualification', prefixIcon: Icons.school_outlined),
                      items: [
                        for (final option in _educationQualificationOptions)
                          DropdownMenuItem(
                            value: option.value,
                            child: Text(option.label, style: fieldStyle),
                          ),
                      ],
                      onChanged: (v) => setState(() => _educationQualification = v ?? 'Diploma'),
                      validator: (v) => v == null || v.isEmpty ? 'Please select your educational qualification' : null,
                    ),
                    _fieldSpacer(),
                    TextFormField(
                      controller: _institution,
                      style: fieldStyle,
                      decoration: AuthSignupTheme.inputDecoration('Institution / university', prefixIcon: Icons.account_balance_outlined),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Institution is required' : null,
                    ),
                    _fieldSpacer(),
                    _uploadButton(
                      label: 'Certifications upload',
                      statusLabel: _certificationsLabel,
                      onPick: () => _pickDocument(
                        (data, name) {
                          _certificationsData = data;
                          _certificationsLabel = name;
                        },
                        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
                      ),
                    ),
                    _fieldSpacer(),
                    _uploadButton(
                      label: 'CV / Resume upload',
                      statusLabel: _cvLabel,
                      onPick: () => _pickDocument((data, name) {
                        _cvData = data;
                        _cvLabel = name;
                      }),
                    ),
                  ]),
                  _section('Document attachments', [
                    _uploadButton(
                      label: 'ID copy',
                      statusLabel: _idCopyLabel,
                      onPick: () => _pickDocument((data, name) {
                        _idCopyData = data;
                        _idCopyLabel = name;
                      }),
                    ),
                    _uploadButton(
                      label: 'Professional license',
                      statusLabel: _licenseDocLabel,
                      onPick: () => _pickDocument((data, name) {
                        _licenseDocData = data;
                        _licenseDocLabel = name;
                      }),
                    ),
                    _uploadButton(
                      label: 'Degree certificate',
                      statusLabel: _degreeCertLabel,
                      onPick: () => _pickDocument((data, name) {
                        _degreeCertData = data;
                        _degreeCertLabel = name;
                      }),
                    ),
                    _uploadButton(
                      label: 'Additional certifications',
                      statusLabel: _additionalCertsLabel,
                      onPick: () => _pickDocument((data, name) {
                        _additionalCertsData = data;
                        _additionalCertsLabel = name;
                      }),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  AuthSignupTheme.primaryButton(
                    label: 'Submit registration',
                    onPressed: _submit,
                    loading: _submitting,
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
