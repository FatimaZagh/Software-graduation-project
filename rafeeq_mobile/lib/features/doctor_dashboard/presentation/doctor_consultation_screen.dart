import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/allergy_display.dart';
import '../data/doctor_portal_api.dart';
import 'doctor_prescribe_screen.dart';

/// Pre-consult file, live session (vitals + attachments), and e-prescription with signature image.
class DoctorConsultationScreen extends StatefulWidget {
  const DoctorConsultationScreen({
    super.key,
    required this.doctorUserId,
    required this.appointmentId,
    required this.patientUserId,
    required this.patientName,
    this.initialBookingStatus,
  });

  final String doctorUserId;
  final String appointmentId;
  final String patientUserId;
  final String patientName;
  final String? initialBookingStatus;

  @override
  State<DoctorConsultationScreen> createState() => _DoctorConsultationScreenState();
}

class _DoctorConsultationScreenState extends State<DoctorConsultationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _pre;
  Map<String, dynamic>? _session;
  final _diagnosis = TextEditingController();
  final _notes = TextEditingController();
  final _w = TextEditingController();
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  final _hr = TextEditingController();
  final _rxRows = <_RxRow>[
    _RxRow(),
  ];
  String _sigB64 = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _diagnosis.dispose();
    _notes.dispose();
    _w.dispose();
    _sys.dispose();
    _dia.dispose();
    _hr.dispose();
    for (final r in _rxRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pre = await DoctorPortalApi.getPreconsult(widget.doctorUserId, widget.patientUserId);
      final ses = await DoctorPortalApi.getSession(widget.doctorUserId, widget.appointmentId);
      if (!mounted) return;
      _pre = pre;
      _session = ses;
      _diagnosis.text = ses['diagnosis']?.toString() ?? '';
      _notes.text = ses['notes']?.toString() ?? '';
      final v = ses['vitals'] as Map<String, dynamic>? ?? {};
      _w.text = v['weightKg']?.toString() ?? '';
      _sys.text = v['bpSystolic']?.toString() ?? '';
      _dia.text = v['bpDiastolic']?.toString() ?? '';
      _hr.text = v['heartRate']?.toString() ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveSession(List<Map<String, dynamic>> attachments) async {
    setState(() => _saving = true);
    try {
      await DoctorPortalApi.putSession(widget.doctorUserId, widget.appointmentId, {
        'diagnosis': _diagnosis.text.trim(),
        'notes': _notes.text.trim(),
        'vitals': {
          'weightKg': num.tryParse(_w.text.trim()),
          'bpSystolic': num.tryParse(_sys.text.trim()),
          'bpDiastolic': num.tryParse(_dia.text.trim()),
          'heartRate': num.tryParse(_hr.text.trim()),
        },
        'attachments': attachments,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.doctorSessionSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAttachment() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (x == null) return;
    final b = await x.readAsBytes();
    final att = [
      {
        'fileName': x.name,
        'mimeType': 'image/jpeg',
        'dataBase64': base64Encode(b),
      }
    ];
    await _saveSession(att);
    await _load();
  }

  Future<void> _pickSignature() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 90);
    if (x == null) return;
    final b = await x.readAsBytes();
    setState(() => _sigB64 = 'data:image/png;base64,${base64Encode(b)}');
  }

  Future<void> _submitRx() async {
    final l10n = AppLocalizations.of(context)!;
    final items = <Map<String, String>>[];
    for (final r in _rxRows) {
      final name = r.name.text.trim();
      if (name.isEmpty) continue;
      final valueErr = validateMedicationDurationValue(r.durationQty.text);
      if (valueErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name: $valueErr')),
        );
        return;
      }
      final duration = buildMedicationDurationString(r.durationQty.text, r.durationUnit);
      items.add({
        'name': name,
        'dosage': r.dosage.text.trim(),
        'duration': duration,
        'instructions': r.instructions.text.trim(),
        'frequency': r.frequency.text.trim(),
      });
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.doctorRxNeedMed)));
      return;
    }
    setState(() => _saving = true);
    try {
      await DoctorPortalApi.postPrescription(widget.doctorUserId, {
        'patientUserId': widget.patientUserId,
        'appointmentId': widget.appointmentId,
        'items': items,
        'signatureImageBase64': _sigB64,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.doctorRxSaved)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientName),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.doctorTabPreconsult),
            Tab(text: l10n.doctorTabSession),
            Tab(text: l10n.doctorTabRx),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _buildPreconsult(l10n),
                _buildSession(l10n),
                _buildRx(l10n),
              ],
            ),
    );
  }

  Widget _buildPreconsult(AppLocalizations l10n) {
    final h = _pre?['healthProfile'] as Map<String, dynamic>? ?? {};
    final p = _pre?['patient'] as Map<String, dynamic>? ?? {};
    final meds = (_pre?['currentMedications'] as List<dynamic>?) ?? [];
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        if (widget.initialBookingStatus == 'Pending') ...[
          Row(
            children: [
              FilledButton(
                onPressed: () async {
                  await DoctorPortalApi.patchBooking(
                    widget.doctorUserId,
                    widget.appointmentId,
                    'Accepted',
                  );
                  if (mounted) Navigator.pop(context, true);
                },
                child: Text(l10n.doctorAccept),
              ),
              SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await DoctorPortalApi.patchBooking(
                    widget.doctorUserId,
                    widget.appointmentId,
                    'Rejected',
                  );
                  if (mounted) Navigator.pop(context, true);
                },
                child: Text(l10n.doctorReject),
              ),
            ],
          ),
          Divider(height: 24),
        ],
        Text(l10n.doctorChronic, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(_joinOrNone(h['chronicDiseases'], l10n.doctorNone)),
        SizedBox(height: 12),
        Text(l10n.doctorAllergies, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(formatAllergiesForDisplay(h['allergies'], emptyPlaceholder: l10n.doctorNone)),
        SizedBox(height: 12),
        Text(l10n.doctorSurgeries, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(_joinOrNone(h['pastSurgeries'], l10n.doctorNone)),
        SizedBox(height: 12),
        Text(l10n.doctorMeds, style: TextStyle(fontWeight: FontWeight.bold)),
        ...meds.map((m) {
          final x = m as Map<String, dynamic>;
          return ListTile(
            dense: true,
            title: Text(x['medicationName']?.toString() ?? ''),
            subtitle: Text('${x['dosage'] ?? ''} · ${x['frequency'] ?? ''}'),
          );
        }),
        SizedBox(height: 12),
        Text(l10n.doctorPrevVisits, style: TextStyle(fontWeight: FontWeight.bold)),
        ...((_pre?['recentAppointments'] as List<dynamic>?) ?? []).map((e) {
          final a = e as Map<String, dynamic>;
          return ListTile(
            dense: true,
            title: Text('${a['date']} ${a['time']}'),
            subtitle: Text(a['status']?.toString() ?? ''),
          );
        }),
        SizedBox(height: 8),
        Text('${l10n.doctorPatientRecord}: ${p['fullName'] ?? ''}', style: TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget _buildSession(AppLocalizations l10n) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        TextField(controller: _diagnosis, decoration: InputDecoration(labelText: l10n.doctorDiagnosis, border: OutlineInputBorder())),
        SizedBox(height: 8),
        TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(labelText: l10n.doctorNotes, border: OutlineInputBorder())),
        SizedBox(height: 12),
        Text(l10n.doctorVitals, style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(child: TextField(controller: _w, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.doctorWeightKg, border: OutlineInputBorder()))),
            SizedBox(width: 8),
            Expanded(child: TextField(controller: _sys, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.doctorBpSys, border: OutlineInputBorder()))),
            SizedBox(width: 8),
            Expanded(child: TextField(controller: _dia, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.doctorBpDia, border: OutlineInputBorder()))),
          ],
        ),
        SizedBox(height: 8),
        TextField(controller: _hr, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.doctorHeartRate, border: OutlineInputBorder())),
        SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _saving ? null : _pickAttachment, icon: Icon(Icons.upload_file), label: Text(l10n.doctorAttachScan)),
        if ((_session?['attachments'] as List<dynamic>? ?? []).isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(l10n.doctorAttachmentsCount(((_session!['attachments'] as List).length))),
          ),
        SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : () => _saveSession([]),
          child: Text(l10n.doctorSaveSession),
        ),
      ],
    );
  }

  Widget _buildRx(AppLocalizations l10n) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        ..._rxRows.map((r) => Card(
              margin: EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    TextField(controller: r.name, decoration: InputDecoration(labelText: l10n.doctorMedName, border: OutlineInputBorder())),
                    TextField(controller: r.dosage, decoration: InputDecoration(labelText: l10n.doctorMedDosage, border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    DoctorMedicationDurationFieldOutlined(
                      quantityController: r.durationQty,
                      unit: r.durationUnit,
                      onUnitChanged: (u) => setState(() => r.durationUnit = u),
                      sectionLabel: l10n.doctorMedDuration,
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: r.instructions, decoration: InputDecoration(labelText: l10n.doctorMedInstructions, border: OutlineInputBorder())),
                    TextField(controller: r.frequency, decoration: InputDecoration(labelText: l10n.doctorMedFrequency, border: OutlineInputBorder())),
                  ],
                ),
              ),
            )),
        TextButton(
          onPressed: () => setState(() => _rxRows.add(_RxRow())),
          child: Text(l10n.doctorAddMedLine),
        ),
        SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _pickSignature, icon: Icon(Icons.draw), label: Text(l10n.doctorPickSignature)),
        if (_sigB64.isNotEmpty) Padding(padding: EdgeInsets.only(top: 8), child: Text(l10n.doctorSignatureReady)),
        SizedBox(height: 16),
        FilledButton(onPressed: _saving ? null : _submitRx, child: Text(l10n.doctorSubmitRx)),
      ],
    );
  }
}

String _joinOrNone(dynamic listField, String noneLabel) {
  final list = (listField as List<dynamic>?) ?? [];
  final s = list.join(', ').trim();
  return s.isEmpty ? noneLabel : s;
}

class _RxRow {
  final name = TextEditingController();
  final dosage = TextEditingController();
  final durationQty = TextEditingController();
  String durationUnit = 'Days';
  final instructions = TextEditingController();
  final frequency = TextEditingController();

  void dispose() {
    name.dispose();
    dosage.dispose();
    durationQty.dispose();
    instructions.dispose();
    frequency.dispose();
  }
}
