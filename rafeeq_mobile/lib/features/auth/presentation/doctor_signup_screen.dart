import 'dart:convert';
import 'dart:io';
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
import 'auth_signup_theme.dart';

const _specialties = [
  'General Practice',
  'Cardiology',
  'Dentistry',
  'Dermatology',
  'Pediatrics',
  'Orthopedics',
  'Neurology',
  'Psychiatry',
  'Radiology',
  'Surgery',
  'Emergency Medicine',
  'Other',
];

const _qualificationOptions = ['Bachelor', 'Board', 'Fellowship', 'MSc', 'PhD'];
const _weekDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const _dayNameToKey = {
  'Sunday': 'Sun',
  'Monday': 'Mon',
  'Tuesday': 'Tue',
  'Wednesday': 'Wed',
  'Thursday': 'Thu',
  'Friday': 'Fri',
  'Saturday': 'Sat',
};
const _scheduleDayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _languages = ['Arabic', 'English', 'French'];
const _genders = ['Male', 'Female'];
const _sessionTypes = ['In-person', 'Online', 'Both'];

class DoctorSignupScreen extends StatefulWidget {
  const DoctorSignupScreen({super.key, this.presetOrgId, this.presetOrgName, this.presetClinicId});

  final String? presetOrgId;
  final String? presetOrgName;
  final String? presetClinicId;

  @override
  State<DoctorSignupScreen> createState() => _DoctorSignupScreenState();
}

class _DoctorSignupScreenState extends State<DoctorSignupScreen> {
  final _page = PageController();
  int _step = 0;
  bool _submitting = false;

  String _profileBase64 = '';
  File? _selectedImageFile;
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String _gender = 'Male';
  DateTime? _birthDate;
  final _address = TextEditingController();
  final _nationality = TextEditingController();
  bool _nationalitySeeded = false;

  String _specialty = 'General Practice';
  final _experience = TextEditingController(text: '0');
  final _license = TextEditingController();
  final _university = TextEditingController();
  final _bio = TextEditingController();
  final Set<String> _qualifications = {'Bachelor'};

  final _fee = TextEditingController(text: '0');
  final _shiftStart = TextEditingController(text: '09:00');
  final _shiftEnd = TextEditingController(text: '17:00');
  final Set<String> _workingDays = {'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday'};
  final Set<String> _selectedLanguages = {'Arabic', 'English'};
  String _sessionType = 'In-person';

  String? _idCardData;
  String? _licenseDocData;
  String? _certData;
  String? _cvData;
  String _idCardLabel = '';
  String _licenseDocLabel = '';
  String _certLabel = '';
  String _cvLabel = '';

  String? _orgId;
  String _orgName = '';
  String? _clinicId;
  String _clinicName = '';
  List<dynamic> _orgs = [];
  List<dynamic> _clinics = [];

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
    _clinicId = widget.presetClinicId;
    _loadOrgs();
  }

  @override
  void dispose() {
    _page.dispose();
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _address.dispose();
    _nationality.dispose();
    _experience.dispose();
    _license.dispose();
    _university.dispose();
    _bio.dispose();
    _fee.dispose();
    _shiftStart.dispose();
    _shiftEnd.dispose();
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
        });
        await _loadClinics();
      }
    } catch (_) {}
  }

  Future<void> _loadClinics() async {
    final oid = _orgId;
    if (oid == null || oid.isEmpty) return;
    try {
      final r = await http.get(Uri.parse('$rafeeqApiBase/api/clinics?orgId=$oid')).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200 && mounted) {
        final list = jsonDecode(r.body) as List<dynamic>;
        setState(() {
          _clinics = list;
          if (_clinicId == null && list.length == 1 && list.first is Map) {
            _clinicId = (list.first as Map)['_id']?.toString();
            _clinicName = (list.first as Map)['name']?.toString() ?? '';
          }
        });
      }
    } catch (_) {}
  }

  bool get _useDesktopImagePicker =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _pickProfile() async {
    try {
      if (_useDesktopImagePicker) {
        await _selectDesktopProfileImage();
        return;
      }

      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 88);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _selectedImageFile = x.path.isNotEmpty ? File(x.path) : null;
        _profileBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (e, stackTrace) {
      debugPrint('Error choosing profile image: $e\n$stackTrace');
    }
  }

  Future<void> _selectDesktopProfileImage() async {
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
      if (!mounted) return;
      setState(() {
        _selectedImageFile = null;
        _profileBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
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

    if (!mounted) return;
    setState(() {
      _selectedImageFile = file;
      _profileBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  MemoryImage? _profileMemoryImage() {
    if (_profileBase64.isEmpty) return null;
    try {
      final parts = _profileBase64.split(',');
      if (parts.length < 2 || parts.last.isEmpty) return null;
      return MemoryImage(base64Decode(parts.last));
    } catch (e) {
      debugPrint('Invalid profile image preview data: $e');
      return null;
    }
  }

  Widget _profilePhotoPreview() {
    const radius = 48.0;
    if (_selectedImageFile != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AuthSignupColors.glassCard,
        child: ClipOval(
          child: Image.file(
            _selectedImageFile!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.add_a_photo, color: AuthSignupColors.gold, size: 32),
          ),
        ),
      );
    }
    final memoryImage = _profileMemoryImage();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AuthSignupColors.glassCard,
      backgroundImage: memoryImage,
      child: memoryImage == null ? const Icon(Icons.add_a_photo, color: AuthSignupColors.gold, size: 32) : null,
    );
  }

  Future<void> _pickDoc(void Function(String data, String name) onDone) async {
    final r = await FilePicker.platform.pickFiles(withData: true);
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final ext = (f.extension ?? 'bin').toLowerCase();
    final mime = ext == 'pdf' ? 'application/pdf' : 'image/jpeg';
    onDone('data:$mime;base64,${base64Encode(bytes)}', f.name);
    if (mounted) setState(() {});
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_fullName.text.trim().isEmpty) {
          _snack('Full name is required');
          return false;
        }
        if (_email.text.trim().isEmpty) {
          _snack('Email is required');
          return false;
        }
        if (_phone.text.trim().isEmpty) {
          _snack('Phone is required');
          return false;
        }
        if (_password.text.length < 6) {
          _snack('Password must be at least 6 characters');
          return false;
        }
        if (_password.text != _confirmPassword.text) {
          _snack('Passwords do not match');
          return false;
        }
        if (_orgId == null || _orgId!.isEmpty) {
          _snack('Please select a facility');
          return false;
        }
        return true;
      case 1:
        final lic = _license.text.trim();
        if (lic.isEmpty) {
          _snack('License number is required');
          return false;
        }
        if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(lic)) {
          _snack('License number must be alphanumeric');
          return false;
        }
        return true;
      case 2:
        if (_workingDays.isEmpty) {
          _snack('Select at least one working day');
          return false;
        }
        return true;
      case 3:
        if (_idCardData == null || _licenseDocData == null) {
          _snack('ID card and medical license uploads are required');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Map<String, dynamic> _buildDynamicSchedule() {
    final start = _shiftStart.text.trim();
    final end = _shiftEnd.text.trim();
    final map = <String, dynamic>{};
    for (final key in _scheduleDayKeys) {
      map[key] = {'enabled': false, 'start': start, 'end': end};
    }
    for (final day in _workingDays) {
      final key = _dayNameToKey[day];
      if (key != null) {
        map[key] = {'enabled': true, 'start': start, 'end': end};
      }
    }
    return map;
  }

  void _next() {
    if (!_validateStep(_step)) return;
    if (_step < 3) {
      setState(() => _step++);
      _page.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
    _page.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _submit() async {
    if (!_validateStep(3) || _submitting) return;
    setState(() => _submitting = true);
    try {
      final body = {
        'orgId': _orgId,
        'clinicId': _clinicId,
        'doctorClinicId': _clinicId,
        'fullName': _fullName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'profileImageUrl': _profileBase64,
        'gender': _gender,
        if (_birthDate != null) 'birthDate': _birthDate!.toIso8601String(),
        'residentialAddress': _address.text.trim(),
        'nationality': _nationality.text.trim(),
        'specialty': _specialty,
        'yearsOfExperience': int.tryParse(_experience.text.trim()) ?? 0,
        'licenseNumber': _license.text.trim().toUpperCase(),
        'qualifications': _qualifications.toList(),
        'education': _university.text.trim(),
        'currentClinic': _clinicName.isNotEmpty ? _clinicName : _orgName,
        if (_orgName.isNotEmpty) 'organizationName': _orgName,
        'bio': _bio.text.trim(),
        'consultationFee': double.tryParse(_fee.text.trim()) ?? 0,
        'workingDays': _workingDays.toList(),
        'workingHours': {'start': _shiftStart.text.trim(), 'end': _shiftEnd.text.trim()},
        'dynamicSchedule': _buildDynamicSchedule(),
        'languages': _selectedLanguages.toList(),
        'sessionType': _sessionType,
        'documents': {
          'idCardUrl': _idCardData,
          'medicalLicenseUrl': _licenseDocData,
          'certificatesUrl': _certData,
          'cvUrl': _cvData,
        },
      };

      final r = await http
          .post(
            Uri.parse('$rafeeqApiBase/api/auth/register/doctor'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));

      if (!mounted) return;
      if (r.statusCode == 201) {
        await _showSuccessDialog();
        if (mounted) Navigator.pop(context);
      } else {
        _snack(r.body);
      }
    } catch (e) {
      if (mounted) _snack('$e');
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
                boxShadow: [BoxShadow(color: AuthSignupColors.gold.withValues(alpha: 0.25), blurRadius: 24)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_outlined, color: AuthSignupColors.gold, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Registration Submitted',
                    style: GoogleFonts.urbanist(color: AuthSignupColors.gold, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your doctor profile is complete and awaiting verification. Your account status is Pending Admin Approval — you will be notified once the clinic administrator activates your access.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(color: Colors.white.withValues(alpha: 0.9), height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AuthSignupColors.gold, foregroundColor: Colors.black, minimumSize: const Size(160, 44)),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Understood', style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final active = i <= _step;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: active ? AuthSignupColors.gold : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _docButton({
    required String label,
    required String? statusLabel,
    required VoidCallback onPick,
  }) {
    final done = statusLabel != null && statusLabel.isNotEmpty;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: done ? AuthSignupColors.goldLight : Colors.white70,
        side: BorderSide(color: done ? AuthSignupColors.gold : Colors.white38),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
      onPressed: onPick,
      icon: Icon(done ? Icons.check_circle_outline : Icons.upload_file, color: done ? AuthSignupColors.gold : Colors.white54),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.urbanist(fontWeight: FontWeight.w600)),
          if (done)
            Text(statusLabel!, style: GoogleFonts.urbanist(fontSize: 11, color: AuthSignupColors.gold.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthSignupColors.scaffoldBlack,
      extendBodyBehindAppBar: true,
      appBar: AuthSignupTheme.authAppBar(context: context, title: context.l10n.authDoctorRegistration),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: AuthSignupTheme.gradientBackgroundDecoration()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    children: [
                      Text('Step ${_step + 1} of 4', style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 10),
                      _stepIndicator(),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1(),
                      _buildStep2(),
                      _buildStep3(),
                      _buildStep4(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      OutlinedButton(
                        style: AuthSignupTheme.outlineButtonStyle(),
                        onPressed: _back,
                        child: Text(_step == 0 ? 'Cancel' : 'Back'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: AuthSignupTheme.primaryButtonStyle().copyWith(
                            minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
                            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 14)),
                          ),
                          onPressed: _submitting ? null : _next,
                          child: Text(_step == 3 ? 'Submit application' : 'Continue'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_submitting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AuthSignupColors.gold),
                    const SizedBox(height: 16),
                    Text('Submitting your application…', style: GoogleFonts.urbanist(color: AuthSignupColors.goldLight)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Basic information', style: GoogleFonts.urbanist(color: AuthSignupColors.gold, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: _pickProfile,
            child: _profilePhotoPreview(),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text('Profile photo', style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12))),
        const SizedBox(height: 20),
        if (_orgs.isNotEmpty)
          DropdownButtonFormField<String>(
            value: _orgId,
            dropdownColor: const Color(0xFF1A1A18),
            style: AuthSignupTheme.fieldTextStyle(),
            decoration: AuthSignupTheme.inputDecoration('Facility / Hospital'),
            items: _orgs.map((o) {
              final m = o as Map;
              final id = m['_id']?.toString() ?? '';
              return DropdownMenuItem(value: id, child: Text(m['name']?.toString() ?? id));
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
          ),
        const SizedBox(height: 12),
        if (_clinics.isNotEmpty)
          DropdownButtonFormField<String>(
            value: _clinicId,
            dropdownColor: const Color(0xFF1A1A18),
            style: AuthSignupTheme.fieldTextStyle(),
            decoration: AuthSignupTheme.inputDecoration('Clinic'),
            items: _clinics.map((c) {
              final m = c as Map;
              final id = m['_id']?.toString() ?? '';
              return DropdownMenuItem(value: id, child: Text(m['name']?.toString() ?? id));
            }).toList(),
            onChanged: (v) {
              final match = _clinics.cast<Map>().where((c) => c['_id']?.toString() == v);
              setState(() {
                _clinicId = v;
                _clinicName = match.isNotEmpty ? match.first['name']?.toString() ?? '' : '';
              });
            },
          ),
        const SizedBox(height: 12),
        TextField(controller: _fullName, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Full name', prefixIcon: Icons.person_outline)),
        const SizedBox(height: 12),
        TextField(controller: _email, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Email', prefixIcon: Icons.email_outlined)),
        const SizedBox(height: 12),
        TextField(controller: _phone, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Phone', prefixIcon: Icons.phone_outlined)),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Password', prefixIcon: Icons.lock_outline)),
        const SizedBox(height: 12),
        TextField(controller: _confirmPassword, obscureText: true, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Confirm password', prefixIcon: Icons.lock_reset)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _gender,
          dropdownColor: const Color(0xFF1A1A18),
          style: AuthSignupTheme.fieldTextStyle(),
          decoration: AuthSignupTheme.inputDecoration('Gender'),
          items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _gender = v ?? _gender),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Date of birth', style: GoogleFonts.urbanist(color: Colors.white70)),
          subtitle: Text(
            _birthDate == null ? 'Not set' : '${_birthDate!.year}-${_birthDate!.month}-${_birthDate!.day}',
            style: GoogleFonts.urbanist(color: AuthSignupColors.goldLight),
          ),
          trailing: IconButton(icon: const Icon(Icons.calendar_month, color: AuthSignupColors.gold), onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime(1990),
              firstDate: DateTime(1940),
              lastDate: DateTime.now(),
            );
            if (d != null) setState(() => _birthDate = d);
          }),
        ),
        TextField(controller: _address, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Residential address')),
        const SizedBox(height: 12),
        TextField(controller: _nationality, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Nationality')),
      ],
    );
  }

  Widget _buildStep2() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Professional credentials', style: GoogleFonts.urbanist(color: AuthSignupColors.gold, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _specialty,
          dropdownColor: const Color(0xFF1A1A18),
          style: AuthSignupTheme.fieldTextStyle(),
          decoration: AuthSignupTheme.inputDecoration('Specialty'),
          items: _specialties.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _specialty = v ?? _specialty),
        ),
        const SizedBox(height: 12),
        TextField(controller: _experience, keyboardType: TextInputType.number, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Years of experience')),
        const SizedBox(height: 12),
        TextField(controller: _license, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Medical license number')),
        const SizedBox(height: 12),
        TextField(controller: _university, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('University / education')),
        const SizedBox(height: 12),
        Text('Qualifications', style: GoogleFonts.urbanist(color: Colors.white70)),
        Wrap(
          spacing: 8,
          children: _qualificationOptions.map((q) {
            final sel = _qualifications.contains(q);
            return FilterChip(
              label: Text(q),
              selected: sel,
              selectedColor: AuthSignupColors.gold.withValues(alpha: 0.35),
              checkmarkColor: AuthSignupColors.gold,
              labelStyle: GoogleFonts.urbanist(color: sel ? AuthSignupColors.goldLight : Colors.white70),
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _qualifications.add(q);
                  } else {
                    _qualifications.remove(q);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(controller: _bio, maxLines: 4, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Professional bio')),
      ],
    );
  }

  Widget _buildStep3() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Clinical configuration', style: GoogleFonts.urbanist(color: AuthSignupColors.gold, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        TextField(controller: _fee, keyboardType: TextInputType.number, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Consultation fee')),
        const SizedBox(height: 12),
        TextField(controller: _shiftStart, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Shift start (HH:MM)')),
        const SizedBox(height: 12),
        TextField(controller: _shiftEnd, style: AuthSignupTheme.fieldTextStyle(), decoration: AuthSignupTheme.inputDecoration('Shift end (HH:MM)')),
        const SizedBox(height: 12),
        Text('Working days', style: GoogleFonts.urbanist(color: Colors.white70)),
        Wrap(
          spacing: 6,
          children: _weekDays.map((d) {
            final sel = _workingDays.contains(d);
            return FilterChip(
              label: Text(d, style: GoogleFonts.urbanist(fontSize: 12)),
              selected: sel,
              selectedColor: AuthSignupColors.gold.withValues(alpha: 0.35),
              onSelected: (v) => setState(() => v ? _workingDays.add(d) : _workingDays.remove(d)),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text('Languages', style: GoogleFonts.urbanist(color: Colors.white70)),
        Wrap(
          spacing: 8,
          children: _languages.map((l) {
            final sel = _selectedLanguages.contains(l);
            return FilterChip(
              label: Text(l),
              selected: sel,
              selectedColor: AuthSignupColors.gold.withValues(alpha: 0.35),
              onSelected: (v) => setState(() => v ? _selectedLanguages.add(l) : _selectedLanguages.remove(l)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text('Session type', style: GoogleFonts.urbanist(color: Colors.white70)),
        ..._sessionTypes.map(
          (t) => RadioListTile<String>(
            title: Text(t, style: GoogleFonts.urbanist(color: Colors.white)),
            value: t,
            groupValue: _sessionType,
            activeColor: AuthSignupColors.gold,
            onChanged: (v) => setState(() => _sessionType = v ?? _sessionType),
          ),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Compliance documents', style: GoogleFonts.urbanist(color: AuthSignupColors.gold, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Upload clear scans of your ID, medical license, and certificates. Files are stored securely with signed access links.',
          style: GoogleFonts.urbanist(color: Colors.white54, height: 1.4),
        ),
        const SizedBox(height: 20),
        _docButton(
          label: 'National ID / Passport',
          statusLabel: _idCardLabel,
          onPick: () => _pickDoc((d, n) {
            _idCardData = d;
            _idCardLabel = n;
          }),
        ),
        const SizedBox(height: 10),
        _docButton(
          label: 'Medical license',
          statusLabel: _licenseDocLabel,
          onPick: () => _pickDoc((d, n) {
            _licenseDocData = d;
            _licenseDocLabel = n;
          }),
        ),
        const SizedBox(height: 10),
        _docButton(
          label: 'Certificates (optional)',
          statusLabel: _certLabel,
          onPick: () => _pickDoc((d, n) {
            _certData = d;
            _certLabel = n;
          }),
        ),
        const SizedBox(height: 10),
        _docButton(
          label: 'CV (optional)',
          statusLabel: _cvLabel,
          onPick: () => _pickDoc((d, n) {
            _cvData = d;
            _cvLabel = n;
          }),
        ),
      ],
    );
  }
}
