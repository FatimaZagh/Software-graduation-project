import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'api_config.dart';
import 'app_locale_scope.dart';
import 'features/patient_dashboard/presentation/patient_home_video_bridge.dart';
import 'l10n/l10n_extensions.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final String patientUserId;

  const ProfileSettingsScreen({super.key, required this.patientUserId});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _accountName = TextEditingController();
  final _accountEmail = TextEditingController();
  final _address = TextEditingController();
  final _age = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  String _gender = '';
  String? _profileImageData;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _accountName.dispose();
    _accountEmail.dispose();
    _address.dispose();
    _age.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$rafeeqApiBase/api/patients/profile/${widget.patientUserId}'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception(res.body);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      _fullName.text = data['fullName']?.toString() ?? '';
      _phone.text = data['phone']?.toString() ?? '';
      _accountName.text = data['accountName']?.toString() ?? '';
      _accountEmail.text = data['accountEmail']?.toString() ?? '';
      _address.text = data['address']?.toString() ?? '';
      _gender = data['gender']?.toString() ?? '';
      final ag = data['age'];
      _age.text = ag == null ? '' : ag.toString();
      _profileImageData = data['profileImage']?.toString();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    await PatientHomeVideoBridge.instance.runWithPausedOverlay(_pickPhotoImpl);
  }

  Future<void> _pickPhotoImpl() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 82,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 900000) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image too large. Pick a smaller photo.')),
        );
        return;
      }
      final b64 = base64Encode(bytes);
      setState(() {
        _profileImageData = 'data:image/jpeg;base64,$b64';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo: $e')));
    }
  }

  void _clearPhoto() => setState(() => _profileImageData = '');

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final pw = _newPassword.text;
    if (pw.isNotEmpty && pw != _confirmPassword.text) {
      messenger.showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'fullName': _fullName.text.trim(),
        'phone': _phone.text.trim(),
        'accountName': _accountName.text.trim(),
        'accountEmail': _accountEmail.text.trim(),
        'address': _address.text.trim(),
        'gender': _gender.trim(),
        'age': _age.text.trim(),
        'profileImage': _profileImageData ?? '',
      };
      if (pw.isNotEmpty) body['newPassword'] = pw;

      final res = await http
          .put(
            Uri.parse('$rafeeqApiBase/api/patients/profile/${widget.patientUserId}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (res.statusCode == 200) {
        _newPassword.clear();
        _confirmPassword.clear();
        messenger.showSnackBar(SnackBar(content: Text(context.l10n.doctorProfileSaved)));
        Navigator.pop(context, true);
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Save failed: ${res.body}')));
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.loginConnectionFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _avatar() {
    final raw = _profileImageData?.trim() ?? '';
    Widget child;
    if (raw.startsWith('data:image') && raw.contains('base64,')) {
      try {
        final b64 = raw.split('base64,').last;
        child = ClipOval(child: Image.memory(base64Decode(b64), fit: BoxFit.cover, width: 96, height: 96));
      } catch (_) {
        child = Icon(Icons.person, size: 48);
      }
    } else {
      child = Icon(Icons.person, size: 48);
    }
    return CircleAvatar(radius: 48, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final loc = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileSettings),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: Text(l10n.retry)),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Personal information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Medical data is edited only under the Health tab in the main dashboard.',
                        style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickPhoto,
                              child: _avatar(),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(onPressed: _pickPhoto, child: Text('Change photo')),
                                TextButton(onPressed: _clearPhoto, child: Text('Remove')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: _fullName,
                        decoration: InputDecoration(
                          labelText: 'Full name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _accountEmail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: l10n.loginEmail,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _address,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(),
                        ),
                        value: _gender.isEmpty ? null : _gender,
                        items: const [
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) => setState(() => _gender = v ?? ''),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _age,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Age',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _accountName,
                        decoration: InputDecoration(
                          labelText: 'Display name (account)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _newPassword,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'New password (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _confirmPassword,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        l10n.language,
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.teal.shade900),
                      ),
                      SizedBox(height: 8),
                      SegmentedButton<Locale>(
                        segments: [
                          ButtonSegment(value: const Locale('en'), label: Text(l10n.english)),
                          ButtonSegment(value: const Locale('ar'), label: Text(l10n.arabic)),
                        ],
                        selected: {loc},
                        onSelectionChanged: (s) {
                          if (s.isEmpty) return;
                          if (s.first.languageCode != loc.languageCode) {
                            MyAppLocaleController.toggleLocale(context);
                          }
                        },
                      ),
                      if (MyAppLocaleController.of(context) == null)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Open the patient dashboard from login for full language switching.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                          ),
                        ),
                      SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(_saving ? l10n.loading : l10n.save),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class MedicalRecordsScreen extends StatefulWidget {
  final String patientUserId;

  const MedicalRecordsScreen({super.key, required this.patientUserId});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$rafeeqApiBase/api/patients/medical-records/${widget.patientUserId}'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception(res.body);
      final list = jsonDecode(res.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.medicalRecords),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                      FilledButton(onPressed: _load, child: Text(l10n.retry)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final m = _items[i] as Map<String, dynamic>;
                    final sample = m['isSample'] == true;
                    final appt = m['appointmentId'];
                    String subtitle = '';
                    if (appt is Map) {
                      subtitle =
                          '${appt['date'] ?? ''} · ${appt['time'] ?? ''} · ${appt['doctorName'] ?? ''}';
                    }
                    final rx = m['prescription'];
                    String rxText = '';
                    if (rx is List && rx.isNotEmpty) {
                      rxText = rx
                          .map((e) {
                            if (e is Map) {
                              return '${e['name'] ?? ''} ${e['dosage'] ?? ''} ${e['frequency'] ?? ''}'
                                  .trim();
                            }
                            return e.toString();
                          })
                          .where((s) => s.isNotEmpty)
                          .join('; ');
                    }
                    return Card(
                      margin: EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          m['diagnosis']?.toString() ?? l10n.patient,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subtitle.isNotEmpty) Text(subtitle),
                            if (m['notes'] != null &&
                                m['notes'].toString().isNotEmpty)
                              Text('${l10n.doctorNotes}: ${m['notes']}'),
                            if (rxText.isNotEmpty) Text('Rx: $rxText'),
                            if (sample)
                              Text(
                                'Sample placeholder',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class PaymentHistoryScreen extends StatefulWidget {
  final String patientUserId;

  const PaymentHistoryScreen({super.key, required this.patientUserId});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$rafeeqApiBase/api/patients/payments/${widget.patientUserId}'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception(res.body);
      final list = jsonDecode(res.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(dynamic v) {
    if (v == null) return '';
    try {
      final d = DateTime.tryParse(v.toString());
      if (d == null) return v.toString();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return v.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentHistory),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                      FilledButton(onPressed: _load, child: Text(l10n.retry)),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(child: Text('No payments yet.'))
                  : ListView.builder(
                      padding: EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final p = _items[i] as Map<String, dynamic>;
                        final sample = p['isSample'] == true;
                        final amt = p['amount'];
                        final cur = p['currency']?.toString() ?? 'ILS';
                        return Card(
                          margin: EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade100,
                              child: Icon(Icons.payments, color: Colors.teal.shade800),
                            ),
                            title: Text(
                              p['description']?.toString() ?? 'Payment',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${_formatDate(p['paidAt'])} · ${p['status'] ?? ''}'
                              '${sample ? ' (sample)' : ''}',
                            ),
                            trailing: Text(
                              '$amt $cur',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.teal.shade900,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
