import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../../api_config.dart';
import '../patient_theme.dart';

/// Structured ADR report bottom sheet for a single medication.
class AdverseReportSheet extends StatefulWidget {
  final String patientUserId;
  final String medicationName;
  final String? prescriptionId;
  /// Prescribing doctor user _id (routes ADR + alerts to the correct clinician).
  final String? prescribingDoctorUserId;

  const AdverseReportSheet({
    super.key,
    required this.patientUserId,
    required this.medicationName,
    this.prescriptionId,
    this.prescribingDoctorUserId,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String patientUserId,
    required String medicationName,
    String? prescriptionId,
    String? prescribingDoctorUserId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kPatientSheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AdverseReportSheet(
          patientUserId: patientUserId,
          medicationName: medicationName,
          prescriptionId: prescriptionId,
          prescribingDoctorUserId: prescribingDoctorUserId,
        ),
      ),
    );
  }

  @override
  State<AdverseReportSheet> createState() => _AdverseReportSheetState();
}

class _AdverseReportSheetState extends State<AdverseReportSheet> {
  bool _loadingOptions = true;
  bool _submitting = false;
  String? _loadError;

  List<String> _problemTypes = [];
  List<String> _symptomOptions = [];
  List<String> _severityLevels = [];
  List<String> _onsetTimes = [];

  String? _problemType;
  final Set<String> _selectedSymptoms = {};
  final _otherSymptomsCtrl = TextEditingController();
  String? _severity;
  String? _onsetTime;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOptions();
  }

  @override
  void dispose() {
    _otherSymptomsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchOptions() async {
    try {
      final res = await http
          .get(Uri.parse('$rafeeqApiBase/api/adverse-reports/options'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw Exception(res.body);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _problemTypes = (data['problemTypes'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _symptomOptions = (data['symptomOptions'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _severityLevels = (data['severityLevels'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _onsetTimes = (data['onsetTimes'] as List?)?.map((e) => e.toString()).toList() ?? [];
        // Defaults so SegmentedButton / radios never show an invalid empty selection.
        if (_problemTypes.isNotEmpty) {
          _problemType ??= _problemTypes.first;
        }
        if (_severityLevels.isNotEmpty) {
          _severity ??= _severityLevels.first;
        }
        if (_onsetTimes.isNotEmpty) {
          _onsetTime ??= _onsetTimes.first;
        }
        _loadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingOptions = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_problemType == null || _severity == null || _onsetTime == null) {
      _snack('Please complete problem type, severity, and onset time.');
      return;
    }
    if (_selectedSymptoms.isEmpty && _otherSymptomsCtrl.text.trim().isEmpty) {
      _snack('Select at least one symptom or describe in Other.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'medicationName': widget.medicationName,
        'problemType': _problemType,
        'symptoms': _selectedSymptoms.toList(),
        'otherSymptoms': _otherSymptomsCtrl.text.trim(),
        'severity': _severity,
        'onsetTime': _onsetTime,
        'additionalNotes': _notesCtrl.text.trim(),
      };
      if (widget.prescriptionId != null && widget.prescriptionId!.isNotEmpty) {
        body['prescriptionId'] = widget.prescriptionId;
      }
      final docId = widget.prescribingDoctorUserId?.trim();
      if (docId != null && docId.isNotEmpty) {
        body['doctorUserId'] = docId;
      }

      final res = await http
          .post(
            Uri.parse('$rafeeqApiBase/api/patients/${widget.patientUserId}/adverse-reports'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 201) {
        final err = jsonDecode(res.body);
        throw Exception(err is Map ? (err['message'] ?? res.body) : res.body);
      }

      final out = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      final critical = out['isCritical'] == true;
      Navigator.pop(context, true);
      _snack(
        critical
            ? 'Urgent report sent. Clinical staff notified immediately.'
            : 'Report submitted. Your care team has been notified.',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to submit: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.urbanist()),
        backgroundColor: success ? const Color(0xFF1E3A2F) : const Color(0xFF3A1515),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: _loadingOptions
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: kPatientGold),
                ),
              )
            : _loadError != null
                ? Text(_loadError!, style: GoogleFonts.urbanist(color: Colors.red.shade300))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade400),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Report Side Effect',
                                style: GoogleFonts.urbanist(
                                  color: kPatientGoldLight,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'بلغ عن مشكلة مع الدواء — ${widget.medicationName}',
                          style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle('1. Problem type'),
                        ..._problemTypes.map((p) => RadioListTile<String>(
                              value: p,
                              groupValue: _problemType,
                              activeColor: kPatientGold,
                              title: Text(p, style: GoogleFonts.urbanist(color: Colors.white)),
                              onChanged: (v) => setState(() => _problemType = v),
                            )),
                        const SizedBox(height: 12),
                        _sectionTitle('2. Symptoms (multi-select)'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _symptomOptions.map((s) {
                            final selected = _selectedSymptoms.contains(s);
                            return FilterChip(
                              label: Text(s, style: GoogleFonts.urbanist(fontSize: 12)),
                              selected: selected,
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _selectedSymptoms.add(s);
                                  } else {
                                    _selectedSymptoms.remove(s);
                                  }
                                });
                              },
                              selectedColor: Colors.amber.withValues(alpha: 0.35),
                              checkmarkColor: kPatientWorkspaceBlack,
                              backgroundColor: kPatientFieldFill,
                              side: BorderSide(color: Colors.amber.withValues(alpha: 0.45)),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _otherSymptomsCtrl,
                          style: GoogleFonts.urbanist(color: Colors.white),
                          decoration: patientInputDec('Other symptoms', hint: 'Describe other...'),
                        ),
                        const SizedBox(height: 16),
                        _sectionTitle('3. Severity'),
                        if (_severityLevels.isEmpty)
                          Text(
                            'Severity options unavailable.',
                            style: GoogleFonts.urbanist(color: Colors.white54),
                          )
                        else
                          SegmentedButton<String>(
                            emptySelectionAllowed: true,
                            segments: _severityLevels
                                .map((s) => ButtonSegment(value: s, label: Text(s)))
                                .toList(),
                            selected: _severity != null && _severityLevels.contains(_severity)
                                ? {_severity!}
                                : {_severityLevels.first},
                            onSelectionChanged: (Set<String> next) {
                              setState(() {
                                if (next.isNotEmpty) {
                                  _severity = next.first;
                                } else if (_severityLevels.isNotEmpty) {
                                  _severity = _severityLevels.first;
                                }
                              });
                            },
                            style: ButtonStyle(
                              foregroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) return kPatientWorkspaceBlack;
                                return Colors.white70;
                              }),
                              backgroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) return kPatientGold;
                                return kPatientFieldFill;
                              }),
                            ),
                          ),
                        const SizedBox(height: 16),
                        _sectionTitle('4. When did it start?'),
                        ..._onsetTimes.map((o) => RadioListTile<String>(
                              value: o,
                              groupValue: _onsetTime,
                              activeColor: kPatientGold,
                              title: Text(o, style: GoogleFonts.urbanist(color: Colors.white)),
                              onChanged: (v) => setState(() => _onsetTime = v),
                            )),
                        const SizedBox(height: 12),
                        _sectionTitle('5. Describe what happened'),
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 4,
                          style: GoogleFonts.urbanist(color: Colors.white),
                          decoration: patientInputDec(
                            'صف شو صار معك بالتفصيل',
                            hint: 'Describe in detail what you experienced...',
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _submitting ? 'Submitting...' : 'Submit report',
                            style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: kPatientGoldDeep,
                            foregroundColor: kPatientWorkspaceBlack,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: GoogleFonts.urbanist(
            color: kPatientGold,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
}
