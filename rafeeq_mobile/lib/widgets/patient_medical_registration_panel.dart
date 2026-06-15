import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _g = Color(0xFFD4AF37);
const Color _gLight = Color(0xFFFFE8A3);
const Color _marble = Color(0xE61A1A1A);
const TextStyle _txt = TextStyle(color: Color(0xFFF5F5F0), fontSize: 15, height: 1.25);

const List<String> _genders = ['Male', 'Female'];
const List<String> _maritalChoices = ['Single', 'Married', 'Divorced', 'Widowed'];
const List<String> _relationshipChoices = ['Parent', 'Sibling', 'Spouse', 'Child', 'Relative', 'Other'];
const List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const List<String> _pregnancyChoices = ['Not pregnant', 'Pregnant', 'Postpartum', 'Unknown'];

List<String> _splitTags(String raw) {
  return raw
      .split(RegExp(r'[,;\n]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

class _MedFileRow {
  _MedFileRow({required this.name, required this.mime, required this.dataUrl});
  final String name;
  final String mime;
  final String dataUrl;
}

/// Patient-only fields (parent supplies name, email, password, profile image, optional orgId).
class PatientMedicalRegistrationPanel extends StatefulWidget {
  const PatientMedicalRegistrationPanel({
    super.key,
    required this.passwordController,
    required this.confirmPasswordController,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  @override
  State<PatientMedicalRegistrationPanel> createState() => PatientMedicalRegistrationPanelState();
}

class PatientMedicalRegistrationPanelState extends State<PatientMedicalRegistrationPanel> {
  final phoneController = TextEditingController();
  final identityController = TextEditingController();
  final cityController = TextEditingController();
  final residentialAddressController = TextEditingController();
  final detailedAddressController = TextEditingController();
  final emergencyNameController = TextEditingController();
  final emergencyPhoneController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final allergyMedsController = TextEditingController();
  final allergyFoodsController = TextEditingController();
  final allergyMaterialsController = TextEditingController();
  final currentMedsController = TextEditingController();
  final pastSurgeriesController = TextEditingController();
  final medicalNotesController = TextEditingController();
  final familyHistoryController = TextEditingController();

  String _gender = '';
  String _maritalStatus = '';
  String _emergencyRelationship = '';
  String _bloodType = '';
  String _pregnancyChoice = '';
  DateTime? _dob;
  DateTime? _lastClinic;
  bool _smoking = false;
  bool _alcohol = false;
  final Set<String> _chronic = {};

  final List<_MedFileRow> _files = [];

  InputDecoration _dec(String label, {IconData? icon}) {
    final enabled = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _g.withValues(alpha: 0.88), width: 1.35),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _g.withValues(alpha: 0.92), fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(color: _gLight, fontWeight: FontWeight.w600),
      prefixIcon: icon == null ? null : Icon(icon, color: _gLight, size: 22),
      filled: true,
      fillColor: _marble,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: enabled,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _gLight, width: 1.65),
      ),
      border: enabled,
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
    String hint = 'Select',
  }) {
    return InputDecorator(
      decoration: _dec(label, icon: icon),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value.isEmpty ? null : value,
          dropdownColor: const Color(0xFF1A2220),
          style: _txt,
          iconEnabledColor: _g,
          hint: Text(hint, style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          items: [
            for (final e in items) DropdownMenuItem<String>(value: e, child: Text(e, style: _txt)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _bumpNumeric(TextEditingController c, double delta, {double? min, double? max}) {
    final raw = c.text.trim();
    double v = double.tryParse(raw) ?? 0;
    v += delta;
    if (min != null && v < min) v = min;
    if (max != null && v > max) v = max;
    if (v == v.roundToDouble()) {
      c.text = v.toInt().toString();
    } else {
      c.text = v.toStringAsFixed(1);
    }
    setState(() {});
  }

  Widget _numericStepRow({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required double step,
    double? min,
    double? max,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
            style: _txt,
            cursorColor: _g,
            decoration: _dec(label, icon: icon),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 4),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
              icon: Icon(Icons.add_circle_outline, color: _gLight.withValues(alpha: 0.95)),
              onPressed: () => _bumpNumeric(controller, step, min: min, max: max),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
              icon: Icon(Icons.remove_circle_outline, color: _gLight.withValues(alpha: 0.95)),
              onPressed: () => _bumpNumeric(controller, -step, min: min, max: max),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showOtherChronicDialog() async {
    final ctrl = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2220),
        title: Text('Other condition', style: GoogleFonts.playfairDisplay(color: _g, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: _txt,
          cursorColor: _g,
          decoration: InputDecoration(
            hintText: 'Type condition name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _g)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gLight)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: _gLight))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _g, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (added != null && added.isNotEmpty) {
      setState(() => _chronic.add(added));
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    identityController.dispose();
    cityController.dispose();
    residentialAddressController.dispose();
    detailedAddressController.dispose();
    emergencyNameController.dispose();
    emergencyPhoneController.dispose();
    heightController.dispose();
    weightController.dispose();
    allergyMedsController.dispose();
    allergyFoodsController.dispose();
    allergyMaterialsController.dispose();
    currentMedsController.dispose();
    pastSurgeriesController.dispose();
    medicalNotesController.dispose();
    familyHistoryController.dispose();
    super.dispose();
  }

  Future<void> _pickMedicalFiles() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    for (final f in r.files) {
      if (f.bytes == null) continue;
      final ext = (f.extension ?? 'bin').toLowerCase();
      String mime = 'application/octet-stream';
      if (ext == 'pdf') mime = 'application/pdf';
      if (ext == 'png') mime = 'image/png';
      if (ext == 'jpg' || ext == 'jpeg') mime = 'image/jpeg';
      final b64 = base64Encode(f.bytes!);
      final dataUrl = 'data:$mime;base64,$b64';
      setState(() {
        _files.add(_MedFileRow(name: f.name, mime: mime, dataUrl: dataUrl));
      });
    }
  }

  String? validateForSubmit() {
    if (widget.passwordController.text != widget.confirmPasswordController.text) {
      return 'Password and confirm password do not match.';
    }
    if (widget.passwordController.text.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (phoneController.text.trim().isEmpty) {
      return 'Phone number is required.';
    }
    if (_gender.isEmpty) {
      return 'Please select gender.';
    }
    return null;
  }

  Map<String, dynamic> buildMedicalRegistrationMap() {
    return {
      'phoneNumber': phoneController.text.trim(),
      'gender': _gender,
      'dateOfBirth': _dob?.toIso8601String().split('T').first,
      'identityNumber': identityController.text.trim(),
      'maritalStatus': _maritalStatus,
      'address': {
        'city': cityController.text.trim(),
        'residentialAddress': residentialAddressController.text.trim(),
        'detailedAddress': detailedAddressController.text.trim(),
      },
      'emergencyContact': {
        'name': emergencyNameController.text.trim(),
        'phone': emergencyPhoneController.text.trim(),
        'relationship': _emergencyRelationship,
      },
      'vitals': {
        'bloodType': _bloodType,
        'height': num.tryParse(heightController.text.trim()),
        'weight': num.tryParse(weightController.text.trim()),
      },
      'medicalHistory': {
        'chronicDiseases': _chronic.toList(),
        'allergies': {
          'medications': _splitTags(allergyMedsController.text),
          'foods': _splitTags(allergyFoodsController.text),
          'materials': _splitTags(allergyMaterialsController.text),
        },
        'currentMedications': _splitTags(currentMedsController.text),
        'pastSurgeries': _splitTags(pastSurgeriesController.text),
        'medicalHistoryNotes': medicalNotesController.text.trim(),
        'familyMedicalHistory': _splitTags(familyHistoryController.text),
      },
      'socialHabits': {'smoking': _smoking, 'alcohol': _alcohol},
      'pregnancyStatus': _gender == 'Female' ? _pregnancyChoice : '',
      'lastClinicVisit': _lastClinic?.toUtc().toIso8601String(),
      'medicalFiles': _files
          .map(
            (e) => {
              'fileUrl': e.dataUrl,
              'fileType': e.mime,
              'originalName': e.name,
            },
          )
          .toList(),
    };
  }

  Widget _chronicChip(String label, String key) {
    final on = _chronic.contains(key);
    return FilterChip(
      label: Text(label, style: GoogleFonts.poppins(color: on ? Colors.black : _gLight, fontSize: 13)),
      selected: on,
      onSelected: (v) => setState(() {
        if (v) {
          _chronic.add(key);
        } else {
          _chronic.remove(key);
        }
      }),
      selectedColor: _g,
      checkmarkColor: Colors.black,
      side: const BorderSide(color: _g),
      backgroundColor: _marble,
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(primary: _g, onPrimary: Colors.black, surface: const Color(0xFF1A2220)),
          ),
          child: child!,
        );
      },
    );
    if (d != null) setState(() => _dob = d);
  }

  Future<void> _pickLastVisit() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _lastClinic ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(primary: _g, onPrimary: Colors.black, surface: const Color(0xFF1A2220)),
          ),
          child: child!,
        );
      },
    );
    if (d != null) setState(() => _lastClinic = d);
  }

  @override
  Widget build(BuildContext context) {
    final showPregnancy = _gender == 'Female';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          title: '1. Account & personal',
          initiallyExpanded: true,
          children: [
            TextField(
              controller: widget.confirmPasswordController,
              obscureText: true,
              style: _txt,
              cursorColor: _g,
              decoration: _dec('Confirm password', icon: Icons.lock_person_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: _txt,
              cursorColor: _g,
              decoration: _dec('Phone', icon: Icons.phone_outlined),
            ),
            const SizedBox(height: 12),
            _dropdown(
              label: 'Gender',
              value: _gender,
              items: _genders,
              icon: Icons.wc_outlined,
              onChanged: (v) {
                setState(() {
                  _gender = v ?? '';
                  if (_gender != 'Female') {
                    _pregnancyChoice = '';
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDob,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: _dec('Date of birth', icon: Icons.calendar_today_outlined),
                child: Text(
                  _dob == null ? 'Tap to choose date' : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
                  style: _txt,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: cityController, style: _txt, cursorColor: _g, decoration: _dec('City', icon: Icons.location_city_outlined)),
            const SizedBox(height: 12),
            TextField(
              controller: residentialAddressController,
              maxLines: 2,
              style: _txt,
              cursorColor: _g,
              decoration: _dec('Residential address', icon: Icons.home_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailedAddressController,
              maxLines: 2,
              style: _txt,
              cursorColor: _g,
              decoration: _dec('Detailed address / district', icon: Icons.map_outlined),
            ),
            const SizedBox(height: 12),
            TextField(controller: identityController, style: _txt, cursorColor: _g, decoration: _dec('ID / Passport (optional)', icon: Icons.badge_outlined)),
            const SizedBox(height: 12),
            _dropdown(
              label: 'Marital status',
              value: _maritalStatus,
              items: _maritalChoices,
              icon: Icons.favorite_outline,
              onChanged: (v) => setState(() => _maritalStatus = v ?? ''),
            ),
          ],
        ),
        _section(
          title: '2. Emergency contact',
          children: [
            TextField(controller: emergencyNameController, style: _txt, cursorColor: _g, decoration: _dec('Contact name', icon: Icons.person_outline)),
            const SizedBox(height: 12),
            TextField(controller: emergencyPhoneController, style: _txt, cursorColor: _g, decoration: _dec('Contact phone', icon: Icons.phone_callback_outlined)),
            const SizedBox(height: 12),
            _dropdown(
              label: 'Relationship',
              value: _emergencyRelationship,
              items: _relationshipChoices,
              icon: Icons.group_outlined,
              onChanged: (v) => setState(() => _emergencyRelationship = v ?? ''),
            ),
          ],
        ),
        _section(
          title: '3. Vitals & medical history',
          children: [
            _dropdown(
              label: 'Blood type',
              value: _bloodType,
              items: _bloodTypes,
              icon: Icons.bloodtype_outlined,
              onChanged: (v) => setState(() => _bloodType = v ?? ''),
            ),
            const SizedBox(height: 12),
            _numericStepRow(
              label: 'Height (cm)',
              controller: heightController,
              icon: Icons.height_rounded,
              step: 1,
              min: 40,
              max: 260,
            ),
            const SizedBox(height: 12),
            _numericStepRow(
              label: 'Weight (kg)',
              controller: weightController,
              icon: Icons.monitor_weight_outlined,
              step: 0.5,
              min: 2,
              max: 400,
            ),
            const SizedBox(height: 14),
            Text('Chronic conditions', style: GoogleFonts.playfairDisplay(color: _g, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chronicChip('Diabetes', 'Diabetes'),
                _chronicChip('Hypertension', 'Hypertension'),
                _chronicChip('Asthma', 'Asthma'),
                _chronicChip('Heart disease', 'Heart Diseases'),
                ActionChip(
                  label: Text('+ Other', style: GoogleFonts.poppins(color: _gLight, fontWeight: FontWeight.w700)),
                  side: const BorderSide(color: _g, width: 1.5),
                  backgroundColor: _marble,
                  onPressed: _showOtherChronicDialog,
                ),
                ..._chronic
                    .where((c) => !['Diabetes', 'Hypertension', 'Asthma', 'Heart Diseases'].contains(c))
                    .map(
                      (c) => InputChip(
                        label: Text(c, style: GoogleFonts.poppins(color: _gLight, fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 16, color: _gLight),
                        onDeleted: () => setState(() => _chronic.remove(c)),
                        side: const BorderSide(color: _g),
                        backgroundColor: _marble,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(controller: allergyMedsController, maxLines: 2, style: _txt, cursorColor: _g, decoration: _dec('Allergies — medications (comma-separated)', icon: Icons.medication_outlined)),
            const SizedBox(height: 12),
            TextField(controller: allergyFoodsController, maxLines: 2, style: _txt, cursorColor: _g, decoration: _dec('Allergies — foods', icon: Icons.restaurant_outlined)),
            const SizedBox(height: 12),
            TextField(controller: allergyMaterialsController, maxLines: 2, style: _txt, cursorColor: _g, decoration: _dec('Allergies — materials', icon: Icons.texture_outlined)),
            const SizedBox(height: 12),
            TextField(controller: currentMedsController, maxLines: 2, style: _txt, cursorColor: _g, decoration: _dec('Current medications', icon: Icons.medication_liquid_outlined)),
            const SizedBox(height: 12),
            TextField(controller: pastSurgeriesController, maxLines: 2, style: _txt, cursorColor: _g, decoration: _dec('Past surgeries', icon: Icons.local_hospital_outlined)),
            const SizedBox(height: 12),
            TextField(controller: medicalNotesController, maxLines: 3, style: _txt, cursorColor: _g, decoration: _dec('Medical history notes', icon: Icons.notes_outlined)),
            const SizedBox(height: 12),
            TextField(controller: familyHistoryController, maxLines: 2, style: _txt, cursorColor: _g, decoration: _dec('Family medical history', icon: Icons.family_restroom_outlined)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    value: _smoking,
                    onChanged: (v) => setState(() => _smoking = v ?? false),
                    title: Text('Smoking', style: GoogleFonts.poppins(color: _gLight, fontSize: 14)),
                    activeColor: _g,
                    checkColor: Colors.black,
                    tileColor: _marble,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _g)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CheckboxListTile(
                    value: _alcohol,
                    onChanged: (v) => setState(() => _alcohol = v ?? false),
                    title: Text('Alcohol', style: GoogleFonts.poppins(color: _gLight, fontSize: 14)),
                    activeColor: _g,
                    checkColor: Colors.black,
                    tileColor: _marble,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _g)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: showPregnancy
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _dropdown(
                          label: 'Pregnancy status',
                          value: _pregnancyChoice,
                          items: _pregnancyChoices,
                          icon: Icons.pregnant_woman_outlined,
                          onChanged: (v) => setState(() => _pregnancyChoice = v ?? ''),
                        ),
                        const SizedBox(height: 12),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            InkWell(
              onTap: _pickLastVisit,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: _dec('Last clinic visit', icon: Icons.event_available_outlined),
                child: Text(
                  _lastClinic == null ? 'Optional — tap to set' : _lastClinic!.toIso8601String().split('T').first,
                  style: _txt,
                ),
              ),
            ),
          ],
        ),
        _section(
          title: '4. Medical documents',
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _gLight,
                side: const BorderSide(color: _g),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              ),
              onPressed: _pickMedicalFiles,
              icon: const Icon(Icons.upload_file_rounded, color: _gLight),
              label: Text('Add PDF or image (PDF, PNG, JPEG)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            if (_files.isEmpty)
              Text('No files selected.', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13))
            else
              for (final f in List<_MedFileRow>.from(_files))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    tileColor: _marble,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _g)),
                    leading: const Icon(Icons.insert_drive_file_outlined, color: _gLight),
                    title: Text(f.name, style: _txt, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(f.mime, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => setState(() => _files.remove(f)),
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  Widget _section({required String title, required List<Widget> children, bool initiallyExpanded = false}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent, splashColor: _g.withValues(alpha: 0.12)),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Text(title, style: GoogleFonts.playfairDisplay(color: _g, fontSize: 17, fontWeight: FontWeight.w700)),
        collapsedIconColor: _gLight,
        iconColor: _gLight,
        children: children,
      ),
    );
  }
}
