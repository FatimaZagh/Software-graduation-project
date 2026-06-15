import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../api_config.dart';
import '../../../l10n/l10n_extensions.dart';
import 'patient_theme.dart';
import 'rafeeq_ai_medical_assistant_screen.dart';
import 'widgets/adverse_report_sheet.dart';
import 'widgets/rafeeq_medication_ai_panel.dart';

/// Patient prescriptions list with premium dark/gold theme and inline AI assistant.
class PatientPrescriptionsScreen extends StatefulWidget {
  final String patientUserId;

  const PatientPrescriptionsScreen({super.key, required this.patientUserId});

  @override
  State<PatientPrescriptionsScreen> createState() => _PatientPrescriptionsScreenState();
}

class _PatientPrescriptionsScreenState extends State<PatientPrescriptionsScreen> with WidgetsBindingObserver {
  final GlobalKey<RafeeqMedicationAiPanelState> _aiPanelKey = GlobalKey();
  List<Map<String, dynamic>> _activeItems = [];
  List<Map<String, dynamic>> _completedItems = [];
  bool _loading = true;
  String? _error;
  String? _glowMedicationId;
  String? selectedMedicationName;
  final Set<String> _toggleBusy = {};

  static const _cardFill = Color(0xFF1E2421);

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  static bool _switchOn(Map<String, dynamic> m) {
    if (m['patientTaking'] == true) return true;
    if (m['isExpired'] == true || m['status'] == 'Expired') return false;
    final start = _parseDate(m['startDate']);
    if (start == null) return false;
    return m['active'] == true;
  }

  static bool _canToggle(Map<String, dynamic> m) {
    if (m['canToggle'] == false) return false;
    if (m['status'] == 'Stopped') return false;
    if (m['isExpired'] == true || m['status'] == 'Expired') return false;
    return true;
  }

  static Map<String, dynamic> _asMap(dynamic e) =>
      e is Map ? Map<String, dynamic>.from(e as Map) : <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$rafeeqApiBase/api/patients/${widget.patientUserId}/medications'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception(res.body);
      final decoded = jsonDecode(res.body);
      List<Map<String, dynamic>> active = [];
      List<Map<String, dynamic>> completed = [];
      if (decoded is Map) {
        active = [
          for (final e in (decoded['active'] as List? ?? [])) _asMap(e),
        ];
        completed = [
          for (final e in (decoded['completed'] as List? ?? [])) _asMap(e),
        ];
      } else if (decoded is List) {
        active = [for (final e in decoded) _asMap(e)];
      }
      if (!mounted) return;
      setState(() {
        _activeItems = active;
        _completedItems = completed;
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

  void _updateMedInLists(String medId, Map<String, dynamic> patch) {
    void apply(List<Map<String, dynamic>> list) {
      final i = list.indexWhere((m) => m['_id']?.toString() == medId);
      if (i >= 0) list[i] = {...list[i], ...patch};
    }

    apply(_activeItems);
    apply(_completedItems);
  }

  Future<bool> _confirmStartToday() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardFill,
        title: Text(
          l10n.patientStartMedicationTitle,
          style: GoogleFonts.urbanist(color: kPatientGoldLight, fontWeight: FontWeight.w700),
        ),
        content: Text(
          l10n.patientStartMedicationBody,
          style: GoogleFonts.urbanist(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: GoogleFonts.urbanist(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kPatientGoldDeep, foregroundColor: Colors.black),
            child: Text(l10n.patientStartToday, style: GoogleFonts.urbanist(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _startMedication(String medId) async {
    if (_toggleBusy.contains(medId)) return;
    setState(() => _toggleBusy.add(medId));
    try {
      final res = await http
          .post(
            Uri.parse(
              '$rafeeqApiBase/api/patients/${widget.patientUserId}/medications/$medId/start',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception(res.body);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final med = _asMap(body['medication']);
      if (med.isNotEmpty) {
        _updateMedInLists(medId, med);
        if (mounted) setState(() {});
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e', style: GoogleFonts.urbanist()),
          backgroundColor: const Color(0xFF3A1515),
        ),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _toggleBusy.remove(medId));
    }
  }

  Future<void> _pauseMedication(String medId) async {
    if (_toggleBusy.contains(medId)) return;
    setState(() => _toggleBusy.add(medId));
    try {
      final res = await http
          .patch(
            Uri.parse('$rafeeqApiBase/api/patients/${widget.patientUserId}/medications/$medId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'active': false}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception(res.body);
      _updateMedInLists(medId, {'active': false, 'patientTaking': false});
      if (mounted) setState(() {});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e', style: GoogleFonts.urbanist()),
          backgroundColor: const Color(0xFF3A1515),
        ),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _toggleBusy.remove(medId));
    }
  }

  Future<void> _onToggleChanged(String medId, Map<String, dynamic> m, bool value) async {
    if (!_canToggle(m)) return;

    if (value) {
      final start = _parseDate(m['startDate']);
      if (start == null) {
        final confirmed = await _confirmStartToday();
        if (!confirmed || !mounted) return;
        await _startMedication(medId);
        return;
      }
      if (m['active'] != true) {
        setState(() => _toggleBusy.add(medId));
        try {
          final res = await http
              .patch(
                Uri.parse('$rafeeqApiBase/api/patients/${widget.patientUserId}/medications/$medId'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'active': true}),
              )
              .timeout(const Duration(seconds: 15));
          if (res.statusCode != 200) throw Exception(res.body);
          await _load();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$e'), backgroundColor: const Color(0xFF3A1515)),
            );
          }
          await _load();
        } finally {
          if (mounted) setState(() => _toggleBusy.remove(medId));
        }
      }
      return;
    }

    await _pauseMedication(medId);
  }

  void _onMedicationTap(String medId, String name) {
    setState(() {
      _glowMedicationId = medId;
      selectedMedicationName = name;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RafeeqAiMedicalAssistantScreen(
          patientUserId: widget.patientUserId,
          preInjectedMedicationName: name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kPatientWorkspaceBlack,
        appBarTheme: AppBarTheme(
          backgroundColor: kPatientWorkspaceBlack,
          foregroundColor: kPatientGoldLight,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        backgroundColor: kPatientWorkspaceBlack,
        appBar: AppBar(
          title: Text(
            l10n.patientMyPrescriptions,
            style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, color: kPatientGoldLight),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: kPatientGold),
              onPressed: _load,
              tooltip: l10n.refresh,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _buildList()),
            RafeeqMedicationAiPanel(
              key: _aiPanelKey,
              patientUserId: widget.patientUserId,
              selectedMedicationName: selectedMedicationName,
              onMedicationSelected: (name) {
                setState(() => selectedMedicationName = name);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final l10n = context.l10n;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPatientGold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: patientBodyStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: kPatientGoldDeep, foregroundColor: Colors.black),
                child: Text(l10n.retry, style: GoogleFonts.urbanist(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }
    if (_activeItems.isEmpty && _completedItems.isEmpty) {
      return Center(
        child: Text(
          l10n.patientNoPrescriptions,
          style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 15),
        ),
      );
    }

    return RefreshIndicator(
      color: kPatientGold,
      backgroundColor: _cardFill,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          if (_activeItems.isNotEmpty) ...[
            Text(
              l10n.patientCurrentPrescriptions,
              style: GoogleFonts.urbanist(
                color: kPatientGoldLight,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _activeItems.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _medicationCard(_activeItems[i], completed: false),
            ],
          ],
          if (_completedItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              l10n.patientCompletedHistory,
              style: GoogleFonts.urbanist(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _completedItems.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _medicationCard(_completedItems[i], completed: true),
            ],
          ],
        ],
      ),
    );
  }

  String? _courseLabel(BuildContext context, Map<String, dynamic> m) {
    final l10n = context.l10n;
    final days = m['durationInDays'];
    final start = _parseDate(m['startDate']);
    final ends = _parseDate(m['endsAt']);
    if (days != null && start == null) {
      return l10n.patientCourseNotStarted('$days');
    }
    if (start != null && ends != null) {
      final s = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      final e = '${ends.year}-${ends.month.toString().padLeft(2, '0')}-${ends.day.toString().padLeft(2, '0')}';
      return l10n.patientStartedEnds(s, e);
    }
    if (days != null) return l10n.patientCourseLength('$days');
    return null;
  }

  Widget _medicationCard(Map<String, dynamic> m, {required bool completed}) {
    final l10n = context.l10n;
    final id = m['_id']?.toString() ?? '';
    final prescribingDoctorUserId = m['prescribingDoctorUserId']?.toString();
    final switchOn = _switchOn(m);
    final canToggle = !completed && _canToggle(m);
    final busy = _toggleBusy.contains(id);
    final name = m['medicationName']?.toString() ?? l10n.patientUnknownMedication;
    final glowing = _glowMedicationId == id || selectedMedicationName == name;
    final course = _courseLabel(context, m);

    return Opacity(
      opacity: completed ? 0.72 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: completed
                ? Colors.white24
                : (glowing ? Colors.amber : Colors.amber.withValues(alpha: 0.35)),
            width: glowing && !completed ? 1.6 : 1,
          ),
          boxShadow: glowing && !completed
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: completed ? null : () => _onMedicationTap(id, name),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Row(
                            children: [
                              Icon(
                                completed ? Icons.history : Icons.medication_liquid,
                                color: completed ? Colors.white38 : Colors.amber.shade300,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.urbanist(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: glowing && !completed ? kPatientGoldLight : Colors.white,
                                    decoration: completed
                                        ? null
                                        : TextDecoration.underline,
                                    decorationColor: Colors.amber.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              if (!completed)
                                Icon(Icons.auto_awesome, size: 16, color: Colors.amber.withValues(alpha: 0.7)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (id.isNotEmpty && !completed) ...[
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Text(l10n.patientStatusActive, style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 11)),
                        Switch(
                          value: switchOn,
                          activeThumbColor: kPatientGold,
                          activeTrackColor: Colors.amber.withValues(alpha: 0.45),
                          onChanged: (canToggle && !busy)
                              ? (v) => _onToggleChanged(id, m, v)
                              : null,
                        ),
                      ],
                    ),
                  ],
                  if (completed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Chip(
                        label: Text(
                          l10n.patientExpired,
                          style: GoogleFonts.urbanist(fontSize: 11, color: Colors.white70),
                        ),
                        backgroundColor: const Color(0xFF2A2A2A),
                        side: BorderSide(color: Colors.white24),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              if (course != null) ...[
                const SizedBox(height: 6),
                Text(course, style: GoogleFonts.urbanist(color: Colors.amber.withValues(alpha: 0.65), fontSize: 12)),
              ],
              const SizedBox(height: 8),
              Text(
                l10n.patientDoseFrequency('${m['dosage'] ?? l10n.patientEmDash}', '${m['frequency'] ?? l10n.patientEmDash}'),
                style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.patientPrescriber('${m['prescribedBy'] ?? l10n.patientEmDash}'),
                style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13),
              ),
              if ((m['notes']?.toString() ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    m['notes'].toString(),
                    style: GoogleFonts.urbanist(color: Colors.white38, fontSize: 12),
                  ),
                ),
              if (!completed) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.patientTapForAiDetails,
                    style: GoogleFonts.urbanist(color: Colors.amber.withValues(alpha: 0.55), fontSize: 11),
                  ),
                ),
                if (switchOn) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => AdverseReportSheet.show(
                        context,
                        patientUserId: widget.patientUserId,
                        medicationName: name,
                        prescriptionId: id.isNotEmpty ? id : null,
                        prescribingDoctorUserId:
                            (prescribingDoctorUserId != null && prescribingDoctorUserId.isNotEmpty)
                                ? prescribingDoctorUserId
                                : null,
                      ),
                      icon: Icon(Icons.report_problem_outlined, color: Colors.amber.shade300, size: 20),
                      label: Text(
                        l10n.patientReportSideEffect,
                        style: GoogleFonts.urbanist(
                          color: Colors.amber.shade200,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.amber.withValues(alpha: 0.55), width: 1.2),
                        backgroundColor: const Color(0xFF2A2218),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Backward-compatible alias used by older navigation paths.
typedef PatientMyMedicationsScreen = PatientPrescriptionsScreen;
