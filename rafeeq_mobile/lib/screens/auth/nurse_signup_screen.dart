import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../api_config.dart';
import '../../tenant_state.dart';

const Color _gold = Color(0xFFD4AF37);
const Color _goldLight = Color(0xFFFFE8A3);
const Color _glass = Color(0xE6101A18);

const _specialties = [
  'Emergency',
  'Pediatrics',
  'Dermatology',
  'Laboratory',
  'Dentistry',
  'Reception',
  'General',
];

const _education = ['Diploma', 'BSc', 'MSc'];
const _employment = ['Full-Time', 'Part-Time', 'Shifts'];
const _genders = ['Male', 'Female'];

class NurseSignupScreen extends StatefulWidget {
  const NurseSignupScreen({super.key, this.presetOrgId, this.presetOrgName});

  final String? presetOrgId;
  final String? presetOrgName;

  @override
  State<NurseSignupScreen> createState() => _NurseSignupScreenState();
}

class _NurseSignupScreenState extends State<NurseSignupScreen> {
  final _scroll = ScrollController();
  bool _submitting = false;
  String _profileBase64 = '';

  final _firstName = TextEditingController();
  final _fatherName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String _gender = 'Female';
  DateTime? _birthDate;

  final _employeeId = TextEditingController();
  String _specialty = 'General';
  final _experienceYears = TextEditingController(text: '0');
  String _educationLevel = 'Diploma';
  final _university = TextEditingController();
  final _licenseNumber = TextEditingController();
  DateTime? _licenseExpiry;
  String _employmentType = 'Full-Time';

  final _address = TextEditingController();
  final _city = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _emergencyRelation = TextEditingController();

  String? _orgId;
  String _orgName = '';
  List<dynamic> _orgs = [];

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
    _fatherName.dispose();
    _lastName.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _employeeId.dispose();
    _experienceYears.dispose();
    _university.dispose();
    _licenseNumber.dispose();
    _address.dispose();
    _city.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _emergencyRelation.dispose();
    super.dispose();
  }

  Future<void> _loadOrgs() async {
    try {
      final r = await http
          .get(Uri.parse('$rafeeqApiBase/api/organizations?includePending=true'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List<dynamic>;
        if (mounted) {
          setState(() {
            _orgs = list;
            if ((_orgId == null || _orgId!.isEmpty) && widget.presetOrgId != null && widget.presetOrgId!.trim().isNotEmpty) {
              _orgId = widget.presetOrgId!.trim();
              _orgName = widget.presetOrgName ?? _orgName;
            } else if ((_orgId == null || _orgId!.isEmpty) && TenantState.instance.orgId.isNotEmpty) {
              final tid = TenantState.instance.orgId;
              final match = list.cast<Map>().where((o) => o['_id']?.toString() == tid);
              if (match.isNotEmpty) {
                _orgId = tid;
                _orgName = match.first['name']?.toString() ?? _orgName;
              }
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() => _profileBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _gold.withValues(alpha: 0.9)),
        prefixIcon: icon == null ? null : Icon(icon, color: _goldLight, size: 22),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _gold.withValues(alpha: 0.5))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _gold, width: 1.5)),
      );

  Widget _section(String title, List<Widget> children) {
    return Card(
      color: _glass,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _gold.withValues(alpha: 0.75), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: GoogleFonts.playfairDisplay(color: _gold, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  String? _resolvedOrgId() {
    if (_orgId != null && _orgId!.trim().isNotEmpty) return _orgId!.trim();
    final preset = widget.presetOrgId?.trim();
    if (preset != null && preset.isNotEmpty) return preset;
    final tenant = TenantState.instance.orgId.trim();
    if (tenant.isNotEmpty) return tenant;
    return null;
  }

  Future<void> _submit() async {
    final orgId = _resolvedOrgId();
    if (orgId == null || orgId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a facility')));
      return;
    }
    final password = _password.text.trim();
    final confirmPassword = _confirmPassword.text.trim();
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print('Submitting password: $password');
    }
    setState(() => _submitting = true);
    try {
      final body = {
        'orgId': orgId,
        'targetOrgId': orgId,
        'firstName': _firstName.text.trim(),
        'fatherName': _fatherName.text.trim(),
        'lastName': _lastName.text.trim(),
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': password,
        'profileImage': _profileBase64,
        'gender': _gender,
        if (_birthDate != null) 'birthDate': _birthDate!.toIso8601String(),
        'employeeId': _employeeId.text.trim(),
        'specialtyOrDepartment': _specialty,
        'experienceYears': int.tryParse(_experienceYears.text.trim()) ?? 0,
        'educationLevel': _educationLevel,
        'university': _university.text.trim(),
        'nursingLicenseNumber': _licenseNumber.text.trim(),
        'licenseNumber': _licenseNumber.text.trim(),
        if (_licenseExpiry != null) 'licenseExpiryDate': _licenseExpiry!.toIso8601String(),
        'employmentType': _employmentType,
        'residentialAddress': _address.text.trim(),
        'city': _city.text.trim(),
        'emergencyContact': {
          'name': _emergencyName.text.trim(),
          'fullName': _emergencyName.text.trim(),
          'phone': _emergencyPhone.text.trim(),
          'relationship': _emergencyRelation.text.trim(),
        },
        'role': 'Nurse',
      };
      final r = await http
          .post(
            Uri.parse('$rafeeqApiBase/api/auth/register/staff'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;
      if (r.statusCode == 201) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _glass,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _gold, width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_top_rounded, color: _gold, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Registration submitted',
                        style: GoogleFonts.playfairDisplay(color: _gold, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your registration profile has been recorded successfully. Your account is currently Pending approval from the Clinic Administrator.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.88), height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final fieldStyle = GoogleFonts.poppins(color: const Color(0xFFF5F5F0), fontSize: 15);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        foregroundColor: _goldLight,
        title: Text('Nurse registration', style: GoogleFonts.playfairDisplay(color: _gold)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A1412), Color(0xFF1A2220), Color(0xFF06100E)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Scrollbar(
                  controller: _scroll,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Clinical staff onboarding',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(color: _gold, fontSize: 26, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Phase 1 — your application (pending admin approval)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        _section('Facility', [
                          DropdownButtonFormField<String>(
                            value: _orgs.any((o) => o['_id']?.toString() == _orgId) ? _orgId : null,
                            dropdownColor: const Color(0xFF1A2220),
                            style: fieldStyle,
                            decoration: _dec('Select facility', icon: Icons.local_hospital_outlined),
                            items: _orgs
                                .map((o) => DropdownMenuItem(
                                      value: o['_id']?.toString(),
                                      child: Text(o['name']?.toString() ?? '', style: fieldStyle),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              final o = _orgs.cast<Map>().firstWhere(
                                    (x) => x['_id']?.toString() == v,
                                    orElse: () => {},
                                  );
                              setState(() {
                                _orgId = v;
                                _orgName = o['name']?.toString() ?? '';
                              });
                            },
                          ),
                          if (_orgName.isNotEmpty)
                            Text('Joining: $_orgName', style: TextStyle(color: _goldLight.withValues(alpha: 0.8))),
                        ]),
                        _section('Core account & identity', [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: const Color(0xFF1A2220),
                                backgroundImage: _profileBase64.isNotEmpty
                                    ? MemoryImage(base64Decode(_profileBase64.split(',').last))
                                    : null,
                                child: _profileBase64.isEmpty
                                    ? const Icon(Icons.person, color: _goldLight, size: 36)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _pickImage,
                                style: OutlinedButton.styleFrom(foregroundColor: _gold, side: const BorderSide(color: _gold)),
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('Profile photo'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(controller: _firstName, style: fieldStyle, decoration: _dec('First name')),
                          TextField(controller: _fatherName, style: fieldStyle, decoration: _dec('Father name')),
                          TextField(controller: _lastName, style: fieldStyle, decoration: _dec('Last name')),
                          TextField(controller: _username, style: fieldStyle, decoration: _dec('Username', icon: Icons.alternate_email)),
                          TextField(controller: _email, style: fieldStyle, decoration: _dec('Email', icon: Icons.mail_outline)),
                          TextField(controller: _phone, style: fieldStyle, decoration: _dec('Phone', icon: Icons.phone_outlined)),
                          TextField(controller: _password, obscureText: true, style: fieldStyle, decoration: _dec('Password', icon: Icons.lock_outline)),
                          TextField(controller: _confirmPassword, obscureText: true, style: fieldStyle, decoration: _dec('Confirm password')),
                          DropdownButtonFormField<String>(
                            value: _gender,
                            dropdownColor: const Color(0xFF1A2220),
                            style: fieldStyle,
                            decoration: _dec('Gender'),
                            items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g, style: fieldStyle))).toList(),
                            onChanged: (v) => setState(() => _gender = v ?? 'Female'),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Birth date', style: fieldStyle),
                            subtitle: Text(
                              _birthDate == null ? 'Not set' : '${_birthDate!.toLocal()}'.split(' ').first,
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_month, color: _gold),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _birthDate ?? DateTime(1995),
                                  firstDate: DateTime(1950),
                                  lastDate: DateTime.now(),
                                );
                                if (d != null) setState(() => _birthDate = d);
                              },
                            ),
                          ),
                        ]),
                        _section('Job experience & credentials', [
                          TextField(controller: _employeeId, style: fieldStyle, decoration: _dec('Employee / national ID')),
                          DropdownButtonFormField<String>(
                            value: _specialty,
                            dropdownColor: const Color(0xFF1A2220),
                            style: fieldStyle,
                            decoration: _dec('Specialty / department interest'),
                            items: _specialties.map((s) => DropdownMenuItem(value: s, child: Text(s, style: fieldStyle))).toList(),
                            onChanged: (v) => setState(() => _specialty = v ?? 'General'),
                          ),
                          TextField(controller: _experienceYears, keyboardType: TextInputType.number, style: fieldStyle, decoration: _dec('Years of experience')),
                          DropdownButtonFormField<String>(
                            value: _educationLevel,
                            dropdownColor: const Color(0xFF1A2220),
                            style: fieldStyle,
                            decoration: _dec('Education level'),
                            items: _education.map((e) => DropdownMenuItem(value: e, child: Text(e, style: fieldStyle))).toList(),
                            onChanged: (v) => setState(() => _educationLevel = v ?? 'Diploma'),
                          ),
                          TextField(controller: _university, style: fieldStyle, decoration: _dec('University')),
                          TextField(controller: _licenseNumber, style: fieldStyle, decoration: _dec('Nursing license number')),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('License expiry', style: fieldStyle),
                            subtitle: Text(
                              _licenseExpiry == null ? 'Not set' : '${_licenseExpiry!.toLocal()}'.split(' ').first,
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.event, color: _gold),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _licenseExpiry ?? DateTime.now().add(const Duration(days: 365)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                                );
                                if (d != null) setState(() => _licenseExpiry = d);
                              },
                            ),
                          ),
                          DropdownButtonFormField<String>(
                            value: _employmentType,
                            dropdownColor: const Color(0xFF1A2220),
                            style: fieldStyle,
                            decoration: _dec('Employment type'),
                            items: _employment.map((e) => DropdownMenuItem(value: e, child: Text(e, style: fieldStyle))).toList(),
                            onChanged: (v) => setState(() => _employmentType = v ?? 'Full-Time'),
                          ),
                        ]),
                        _section('Contact & emergency', [
                          TextField(controller: _address, style: fieldStyle, decoration: _dec('Residential address')),
                          TextField(controller: _city, style: fieldStyle, decoration: _dec('City')),
                          TextField(controller: _emergencyName, style: fieldStyle, decoration: _dec('Emergency contact name')),
                          TextField(controller: _emergencyPhone, style: fieldStyle, decoration: _dec('Emergency phone')),
                          TextField(controller: _emergencyRelation, style: fieldStyle, decoration: _dec('Relationship')),
                        ]),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text('Submit application', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
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
