import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../utils/diagnostic_attachment_view.dart';
import '../../auth/presentation/auth_signup_theme.dart';
import '../data/diagnostic_api.dart';
import 'lab_result_formatted_view.dart';

enum DiagnosticResultsKind { lab, radiology }

/// Doctor inbox — completed lab or radiology reports with patient demographics.
class DoctorDiagnosticResultsScreen extends StatefulWidget {
  const DoctorDiagnosticResultsScreen({
    super.key,
    required this.doctorUserId,
    required this.kind,
  });

  final String doctorUserId;
  final DiagnosticResultsKind kind;

  @override
  State<DoctorDiagnosticResultsScreen> createState() => _DoctorDiagnosticResultsScreenState();
}

class _DoctorDiagnosticResultsScreenState extends State<DoctorDiagnosticResultsScreen> {
  late final DiagnosticApi _api = DiagnosticApi(userId: widget.doctorUserId);
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  String get _title => widget.kind == DiagnosticResultsKind.lab ? 'Lab Results' : 'Radiology Results';

  @override
  void initState() {
    super.initState();
    _load(markAllRead: true);
  }

  Future<void> _load({bool markAllRead = false}) async {
    setState(() => _loading = true);
    try {
      final list = widget.kind == DiagnosticResultsKind.lab
          ? await _api.doctorCompletedLab()
          : await _api.doctorCompletedRadiology();
      if (markAllRead) {
        for (final item in list) {
          if (item['isReadByDoctor'] != true) {
            final id = item['_id']?.toString() ?? '';
            if (id.isNotEmpty) {
              try {
                if (widget.kind == DiagnosticResultsKind.lab) {
                  await _api.markLabRead(id);
                } else {
                  await _api.markRadiologyRead(id);
                }
              } catch (_) {}
            }
          }
        }
      }
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _testLabel(Map<String, dynamic> m) {
    if (widget.kind == DiagnosticResultsKind.lab) {
      return m['testName']?.toString() ?? 'Lab test';
    }
    return '${m['studyName'] ?? 'Study'} · ${m['modality'] ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthSignupColors.scaffoldBlack,
      appBar: AuthSignupTheme.authAppBar(context: context, title: _title),
      body: Container(
        decoration: AuthSignupTheme.gradientBackgroundDecoration(),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AuthSignupColors.gold))
            : _items.isEmpty
                ? Center(
                    child: Text(
                      'No completed reports yet',
                      style: GoogleFonts.urbanist(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final m = _items[i];
                      final patient = m['patient'] is Map ? Map<String, dynamic>.from(m['patient'] as Map) : <String, dynamic>{};
                      final ageGender = [
                        if (patient['age'] != null) '${patient['age']} yrs',
                        if ((patient['gender']?.toString() ?? '').isNotEmpty) patient['gender'].toString(),
                      ].join(' · ');
                      return Card(
                        color: AuthSignupColors.glassCard,
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AuthSignupColors.gold.withValues(alpha: 0.55)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _testLabel(m),
                                style: GoogleFonts.urbanist(
                                  color: AuthSignupColors.goldLight,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _row('Patient ID', patient['patientId']?.toString() ?? patient['id']?.toString() ?? '—'),
                              _row('Full name', patient['fullName']?.toString() ?? '—'),
                              _row('Age / Gender', ageGender.isEmpty ? '—' : ageGender),
                              _row('Clinic', m['clinicName']?.toString() ?? '—'),
                              const Divider(color: Colors.white12, height: 20),
                              if (widget.kind == DiagnosticResultsKind.lab)
                                LabResultFormattedView(
                                  resultAnalysis: m['resultAnalysis']?.toString(),
                                  fallbackTestType: m['testType']?.toString(),
                                )
                              else
                                _buildRadiologyResultView(m),
                              if (m['attachment'] is Map) ...[
                                Builder(
                                  builder: (context) {
                                    final att = Map<String, dynamic>.from(m['attachment'] as Map);
                                    final fileUrl = att['fileUrl']?.toString() ?? '';
                                    if (fileUrl.isEmpty) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: OutlinedButton.icon(
                                        style: AuthSignupTheme.outlineButtonStyle(),
                                        onPressed: () => openDiagnosticAttachment(
                                          context,
                                          url: fileUrl,
                                          fileName: att['fileName']?.toString(),
                                          mimeType: att['mimeType']?.toString(),
                                        ),
                                        icon: const Icon(Icons.attach_file, color: AuthSignupColors.gold, size: 18),
                                        label: Text(
                                          att['fileName']?.toString() ?? 'View attachment',
                                          style: GoogleFonts.urbanist(color: AuthSignupColors.goldLight, fontSize: 13),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildRadiologyResultView(Map<String, dynamic> m) {
    final parsed = LabResultFormattedView.tryParse(m['resultAnalysis']?.toString());
    if (parsed != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_str(parsed['examDateDisplay']).isNotEmpty)
            _row('Exam Date', _str(parsed['examDateDisplay'])),
          if (_str(parsed['technicianName']).isNotEmpty)
            _row('Technician', _str(parsed['technicianName'])),
          if (_str(parsed['examType']).isNotEmpty) _row('Exam Type', _str(parsed['examType'])),
          if (_str(parsed['bodyPartExamined']).isNotEmpty)
            _row('Body Part', _str(parsed['bodyPartExamined'])),
          if (_str(parsed['technicianNotes']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _str(parsed['technicianNotes']),
              style: GoogleFonts.urbanist(color: Colors.white70, height: 1.45, fontSize: 13),
            ),
          ],
        ],
      );
    }
    return Text(
      m['resultAnalysis']?.toString() ?? 'No analysis text',
      style: GoogleFonts.urbanist(color: Colors.white70, height: 1.45),
    );
  }

  String _str(dynamic v) => v == null ? '' : v.toString().trim();

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: GoogleFonts.urbanist(color: AuthSignupColors.gold, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
