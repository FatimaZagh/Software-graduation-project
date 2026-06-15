import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/doctor_workspace_api.dart';
import 'doctor_chat_room_screen.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);

/// High-priority ADR / CDSS workspace for a single adverse report.
class DoctorAdrDetailScreen extends StatefulWidget {
  const DoctorAdrDetailScreen({
    super.key,
    required this.api,
    required this.initialReport,
  });

  final DoctorWorkspaceApi api;
  final Map<String, dynamic> initialReport;

  @override
  State<DoctorAdrDetailScreen> createState() => _DoctorAdrDetailScreenState();
}

class _DoctorAdrDetailScreenState extends State<DoctorAdrDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;
  late AnimationController _flashCtrl;

  final _replaceNameCtrl = TextEditingController();
  final _replaceDosageCtrl = TextEditingController();
  final _replaceFreqCtrl = TextEditingController();
  final _allergyClassCtrl = TextEditingController();
  final _allergySevCtrl = TextEditingController();
  bool _busy = false;

  String get _reportId =>
      widget.initialReport['_id']?.toString() ?? widget.initialReport['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _load();
  }

  void _syncFlash(bool emergency) {
    if (!mounted) return;
    if (emergency) {
      if (!_flashCtrl.isAnimating) _flashCtrl.repeat(reverse: true);
    } else {
      _flashCtrl.stop();
      _flashCtrl.reset();
    }
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    _replaceNameCtrl.dispose();
    _replaceDosageCtrl.dispose();
    _replaceFreqCtrl.dispose();
    _allergyClassCtrl.dispose();
    _allergySevCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_reportId.isEmpty) {
      setState(() {
        _error = 'Invalid report';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.api.getAdverseReportDetail(_reportId);
      if (!mounted) return;
      final rep = Map<String, dynamic>.from(d['report'] as Map? ?? {});
      setState(() {
        _detail = d;
        _loading = false;
      });
      _syncFlash(rep['isEmergencyCase'] == true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> get _rep {
    if (_detail != null && _detail!['report'] is Map) {
      return Map<String, dynamic>.from(_detail!['report'] as Map);
    }
    return widget.initialReport;
  }

  Map<String, dynamic> get _patient {
    if (_detail != null && _detail!['patient'] is Map) {
      return Map<String, dynamic>.from(_detail!['patient'] as Map);
    }
    return {};
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _dangerBadge(String severity) {
    Color bg;
    Color fg = Colors.black87;
    switch (severity) {
      case 'Severe':
        bg = Colors.red.shade700;
        fg = Colors.white;
        break;
      case 'Moderate':
        bg = Colors.deepOrange.shade600;
        fg = Colors.white;
        break;
      default:
        bg = Colors.amber.shade600;
    }
    if (_rep['isCritical'] == true || _rep['isEmergencyCase'] == true) {
      bg = Colors.red.shade900;
      fg = Colors.white;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        severity,
        style: GoogleFonts.urbanist(color: fg, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }

  void _openPatientChatRoom() {
    final patientUserId = _patient['patientUserId']?.toString() ?? '';
    if (patientUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient ID missing — cannot open chat.')),
      );
      return;
    }
    final med = _rep['medicationName']?.toString() ?? 'this medication';
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DoctorChatRoomScreen(
          api: widget.api,
          patientUserId: patientUserId,
          patientName: _patient['name']?.toString() ?? 'Patient',
          contextBanner: 'ADR follow-up · $med',
          initialDraft:
              'Hello — I reviewed your adverse drug report regarding $med. Please reply here if you have questions or new symptoms.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: _kGold)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: _kGoldLight, title: const Text('ADR')),
        body: Center(child: Text(_error!, style: const TextStyle(color: Colors.white70))),
      );
    }

    final sev = _rep['severity']?.toString() ?? '—';
    final symptoms = (_rep['symptoms'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    if (_rep['otherSymptoms'] != null && '${_rep['otherSymptoms']}'.trim().isNotEmpty) {
      symptoms.add('Other: ${_rep['otherSymptoms']}');
    }
    final patientName = _patient['name']?.toString() ?? 'Patient';
    final emergency = _rep['isEmergencyCase'] == true;

    Widget shell({required Widget child}) {
      if (!emergency) return child;
      return AnimatedBuilder(
        animation: _flashCtrl,
        builder: (_, w) {
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.withValues(alpha: 0.3 + _flashCtrl.value * 0.55), width: 3),
            ),
            child: w,
          );
        },
        child: child,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0D),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: _kGoldLight,
        title: Text('ADR — ${_rep['medicationName'] ?? ''}', style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: shell(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patientName, style: GoogleFonts.urbanist(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            'Medication: ${_rep['medicationName'] ?? '—'}',
                            style: GoogleFonts.urbanist(color: _kGoldLight, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Submitted: ${_rep['createdAt'] ?? '—'}',
                            style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _dangerBadge(sev),
                  ],
                ),
                if (emergency)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'EMERGENCY CASE — highest queue priority',
                      style: GoogleFonts.urbanist(color: Colors.redAccent.shade100, fontWeight: FontWeight.w900),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Reported symptoms', style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (symptoms.isEmpty)
                  Text('—', style: GoogleFonts.urbanist(color: Colors.white54))
                else
                  ...symptoms.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.white70)),
                          Expanded(child: Text(s, style: GoogleFonts.urbanist(color: Colors.white))),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text('Patient communication', style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _openPatientChatRoom,
                        icon: const Icon(Icons.chat_bubble_outline, color: _kGoldLight, size: 18),
                        label: Text('Chat', style: GoogleFonts.urbanist(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: _kGold.withValues(alpha: 0.55)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _run(() => widget.api.postAdrErRedirect(_reportId)),
                        icon: const Icon(Icons.local_hospital, color: Colors.redAccent, size: 18),
                        label: Text(
                          'ER redirection flag',
                          style: GoogleFonts.urbanist(color: Colors.white, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.65)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Replace medication', style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700)),
                TextField(
                  controller: _replaceNameCtrl,
                  style: GoogleFonts.urbanist(color: Colors.white),
                  decoration: _dec('Replacement drug name *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _replaceDosageCtrl,
                  style: GoogleFonts.urbanist(color: Colors.white),
                  decoration: _dec('Dosage'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _replaceFreqCtrl,
                  style: GoogleFonts.urbanist(color: Colors.white),
                  decoration: _dec('Frequency'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            await widget.api.postAdrReplaceMedication(
                              _reportId,
                              replacementName: _replaceNameCtrl.text.trim(),
                              replacementDosage: _replaceDosageCtrl.text.trim().isEmpty ? null : _replaceDosageCtrl.text.trim(),
                              replacementFrequency: _replaceFreqCtrl.text.trim().isEmpty ? null : _replaceFreqCtrl.text.trim(),
                            );
                          }),
                  child: Text('Replace & notify patient', style: GoogleFonts.urbanist(color: _kGoldLight)),
                ),
                const SizedBox(height: 24),
                Text('Allergy registry', style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700)),
                TextField(
                  controller: _allergyClassCtrl,
                  style: GoogleFonts.urbanist(color: Colors.white),
                  decoration: _dec('Drug class (optional)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _allergySevCtrl,
                  style: GoogleFonts.urbanist(color: Colors.white),
                  decoration: _dec('Severity label'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            await widget.api.postAdrAllergyProfile(
                              _reportId,
                              drugName: _rep['medicationName']?.toString(),
                              drugClass: _allergyClassCtrl.text.trim().isEmpty ? null : _allergyClassCtrl.text.trim(),
                              severity: _allergySevCtrl.text.trim().isEmpty ? null : _allergySevCtrl.text.trim(),
                            );
                          }),
                  child: Text('Save to allergy profile', style: GoogleFonts.urbanist(color: Colors.amber.shade200)),
                ),
                const SizedBox(height: 32),
              ],
            ),
            if (_busy) const Positioned.fill(child: ModalBarrier(dismissible: false, color: Colors.black26)),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.urbanist(color: _kGold.withValues(alpha: 0.9)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _kGold.withValues(alpha: 0.45))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _kGold, width: 1.5)),
      );
}
