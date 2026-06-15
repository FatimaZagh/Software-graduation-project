import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../utils/allergy_display.dart';
import '../data/nurse_portal_api.dart';
import 'lab_result_dynamic_form.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kGlass = Color(0xE6101A18);

Widget _title(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(t, style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 20, fontWeight: FontWeight.w700)),
    );

InputDecoration _dec(String l, {IconData? icon}) => InputDecoration(
      labelText: l,
      labelStyle: const TextStyle(color: _kGold),
      prefixIcon: icon == null ? null : Icon(icon, color: _kGold),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _kGold.withValues(alpha: 0.5))),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _kGold)),
    );

void _showNurseSnack(BuildContext context, Object e, {bool quiet = false}) {
  if (quiet) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(nurseFriendlyError(e)),
      backgroundColor: const Color(0xFF1A1510),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class NurseScroll extends StatelessWidget {
  const NurseScroll({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: child,
      );
}

class _PatientBanner extends StatelessWidget {
  const _PatientBanner({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return Card(
        color: _kGlass,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(context.l10n.nurseSelectPatientHint, style: const TextStyle(color: Colors.white54)),
        ),
      );
    }
    return Card(
      color: _kGlass,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: _kGold)),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          tileColor: Colors.transparent,
          leading: const Icon(Icons.person, color: _kGold),
          title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

typedef PatientSelect = void Function(String? id, String label);

class NursePatientsTab extends StatefulWidget {
  const NursePatientsTab({super.key, required this.api, required this.onSelectPatient});
  final NursePortalApi api;
  final PatientSelect onSelectPatient;
  @override
  State<NursePatientsTab> createState() => _NursePatientsTabState();
}

class _ReadOnlyClinicalRow extends StatelessWidget {
  const _ReadOnlyClinicalRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(color: _kGold.withValues(alpha: 0.85), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? '—' : value,
            style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.92), fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Read-only clinical glance — no PII, no edit controls.
class _NursePatientClinicalSheet extends StatefulWidget {
  const _NursePatientClinicalSheet({
    required this.api,
    required this.patientId,
    required this.fallbackName,
  });

  final NursePortalApi api;
  final String patientId;
  final String fallbackName;

  @override
  State<_NursePatientClinicalSheet> createState() => _NursePatientClinicalSheetState();
}

class _NursePatientClinicalSheetState extends State<_NursePatientClinicalSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.get('/patients/${widget.patientId}/clinical-summary');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(r as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = nurseFriendlyError(e);
        _loading = false;
      });
    }
  }

  String _chipList(S l10n, String key) {
    final raw = _data[key];
    if (key == 'allergies') {
      return formatAllergiesForDisplay(raw, emptyPlaceholder: l10n.nurseNoneRecorded);
    }
    if (raw is List && raw.isNotEmpty) return raw.map((e) => e.toString()).join(', ');
    return l10n.nurseNoneRecorded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final rawName = _data['displayName']?.toString().trim() ?? '';
    final name = rawName.isEmpty ? widget.fallbackName : rawName;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1210),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.circular(16)),
        border: Border.all(color: _kGold.withValues(alpha: 0.7), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined, color: _kGold, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.nurseClinicalSummary,
                        style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        l10n.nurseReadOnlyEssentials,
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: _kGold),
                  )
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _kGlass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _kGold.withValues(alpha: 0.15),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: _kGold, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: GoogleFonts.playfairDisplay(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ReadOnlyClinicalRow(
                              label: l10n.nurseAgeDob,
                              value: _data['ageOrDobLabel']?.toString() ?? '—',
                            ),
                            _ReadOnlyClinicalRow(label: l10n.nurseGender, value: _data['gender']?.toString() ?? '—'),
                            _ReadOnlyClinicalRow(label: l10n.nurseBloodType, value: _data['bloodType']?.toString() ?? '—'),
                            _ReadOnlyClinicalRow(label: l10n.nurseChronicConditions, value: _chipList(l10n, 'chronicConditions')),
                            _ReadOnlyClinicalRow(label: l10n.nurseActiveAllergies, value: _chipList(l10n, 'allergies')),
                            const SizedBox(height: 8),
                            Text(
                              l10n.nursePrivacyDisclaimer,
                              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11, height: 1.35),
                            ),
                          ],
                        ),
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kGold,
                    side: const BorderSide(color: _kGold),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(l10n.nurseClose),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NursePatientsTabState extends State<NursePatientsTab> {
  final _q = TextEditingController();
  List<dynamic> _rows = [];
  bool _loading = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final r = await widget.api.get('/patients', query: _q.text.trim().isEmpty ? null : {'q': _q.text.trim()});
      if (mounted) setState(() { _rows = r is List ? r : []; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showNurseSnack(context, e, quiet: nurseIsPermissionDenied(e));
      }
    }
  }

  void _openClinicalSheet(String id, String name) {
    if (id.isEmpty) return;
    widget.onSelectPatient(id, name);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NursePatientClinicalSheet(api: widget.api, patientId: id, fallbackName: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NurseScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context.l10n.nursePatientRegistry),
          Text(
            context.l10n.nurseSearchPatientHint,
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _q,
            style: const TextStyle(color: Colors.white),
            decoration: _dec(context.l10n.nurseSearchByName, icon: Icons.search),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.search, size: 18),
              label: Text(context.l10n.nurseSearchPatients),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(color: _kGold),
          if (!_loading && _rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                context.l10n.nurseNoPatientsLoaded,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
              ),
            ),
          ..._rows.map((raw) {
            final p = Map<String, dynamic>.from(raw as Map);
            final name = p['displayName']?.toString() ?? p['fullName']?.toString() ?? context.l10n.nursePatientFallback;
            final id = p['userId']?.toString() ?? '';
            final blood = p['bloodType']?.toString() ?? '';
            final gender = p['gender']?.toString() ?? '';
            final subtitle = [if (blood.isNotEmpty) blood, if (gender.isNotEmpty) gender].join(' · ');
            return Card(
              color: _kGlass,
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  tileColor: Colors.transparent,
                  title: Text(name, style: const TextStyle(color: Colors.white)),
                  subtitle: subtitle.isEmpty
                      ? Text(context.l10n.nurseTapClinicalSummary, style: const TextStyle(color: Colors.white38, fontSize: 12))
                      : Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.medical_information_outlined, color: _kGold),
                  onTap: () => _openClinicalSheet(id, name),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class NurseTriageTab extends StatefulWidget {
  const NurseTriageTab({super.key, required this.api, required this.onSelectPatient});
  final NursePortalApi api;
  final PatientSelect onSelectPatient;
  @override
  State<NurseTriageTab> createState() => _NurseTriageTabState();
}

class _NurseTriageTabState extends State<NurseTriageTab> {
  List<dynamic> _queue = [];
  bool _loading = false;
  bool _accessDenied = false;
  final _symptoms = TextEditingController();

  @override
  void dispose() {
    _symptoms.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _accessDenied = false;
    });
    try {
      final r = await widget.api.get('/queue/today');
      if (mounted) {
        setState(() {
          _queue = r is List ? r : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (nurseIsPermissionDenied(e)) {
          _accessDenied = true;
          _queue = [];
        }
      });
      if (!nurseIsPermissionDenied(e)) {
        _showNurseSnack(context, e);
      }
    }
  }

  Future<void> _checkIn(String visitId) async {
    try {
      await widget.api.post('/visits/$visitId/check-in', {});
      await _load();
    } catch (e) {
      if (mounted) _showNurseSnack(context, e, quiet: nurseIsPermissionDenied(e));
    }
  }

  Future<void> _forward(String visitId, String? patientId, String name) async {
    try {
      await widget.api.post('/visits/$visitId/triage', {
        'initialSymptoms': _symptoms.text.trim(),
        'forwardToDoctor': true,
      });
      if (patientId != null) widget.onSelectPatient(patientId, name);
      _symptoms.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.nurseForwardedToDoctor)),
        );
      }
    } catch (e) {
      if (mounted) _showNurseSnack(context, e, quiet: nurseIsPermissionDenied(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return NurseScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context.l10n.nurseDailyTriageDesk),
          if (_accessDenied)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kGold.withValues(alpha: 0.45)),
              ),
              child: Text(
                context.l10n.nurseTriageAccessDenied,
                style: GoogleFonts.poppins(color: Colors.white70, height: 1.4, fontSize: 13),
              ),
            )
          else ...[
            TextField(
              controller: _symptoms,
              style: const TextStyle(color: Colors.white),
              decoration: _dec(context.l10n.nurseSymptomsForVisit),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
                  onPressed: _loading ? null : _load,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_queue.isEmpty ? context.l10n.nurseLoadTodaysQueue : context.l10n.nurseRefreshQueue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._queue.map((raw) {
              final a = Map<String, dynamic>.from(raw as Map);
              final id = a['_id']?.toString() ?? '';
              final pid = a['patientId']?.toString();
              final name = a['patientName']?.toString() ?? context.l10n.nursePatientFallback;
              final status = a['nurseQueueStatus']?.toString() ?? a['status']?.toString() ?? '';
              return Card(
                color: _kGlass,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$name · ${a['time']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text('Dr. ${a['doctorName'] ?? '—'} · $status', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(onPressed: () => _checkIn(id), child: Text(context.l10n.nurseCheckIn)),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
                          onPressed: () => _forward(id, pid, name),
                          child: Text(context.l10n.nurseForwardToDoctor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          ],
        ],
      ),
    );
  }
}

class NurseVitalsTab extends StatefulWidget {
  const NurseVitalsTab({super.key, required this.api, this.patientId, this.patientLabel = ''});
  final NursePortalApi api;
  final String? patientId;
  final String patientLabel;
  @override
  State<NurseVitalsTab> createState() => _NurseVitalsTabState();
}

class _NurseVitalsTabState extends State<NurseVitalsTab> {
  final _bp = TextEditingController();
  final _temp = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _pulse = TextEditingController();
  final _o2 = TextEditingController();
  final _sugar = TextEditingController();
  List<dynamic> _timeline = [];

  @override
  void dispose() {
    for (final c in [_bp, _temp, _weight, _height, _pulse, _o2, _sugar]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTimeline() async {
    final pid = widget.patientId;
    if (pid == null || pid.isEmpty) return;
    try {
      final r = await widget.api.get('/patients/$pid/file');
      if (mounted) setState(() => _timeline = (r as Map)['vitalsTimeline'] as List? ?? []);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant NurseVitalsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) _loadTimeline();
  }

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _save() async {
    final pid = widget.patientId;
    if (pid == null || pid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.nurseSelectPatientFirst)));
      return;
    }
    await widget.api.post('/vitals/$pid', {
      'bloodPressure': _bp.text.trim(),
      if (_temp.text.isNotEmpty) 'temperature': double.tryParse(_temp.text),
      if (_weight.text.isNotEmpty) 'weight': double.tryParse(_weight.text),
      if (_height.text.isNotEmpty) 'height': double.tryParse(_height.text),
      if (_pulse.text.isNotEmpty) 'pulse': double.tryParse(_pulse.text),
      if (_o2.text.isNotEmpty) 'oxygenSaturation': double.tryParse(_o2.text),
      if (_sugar.text.isNotEmpty) 'bloodSugar': double.tryParse(_sugar.text),
    });
    await _loadTimeline();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.nurseVitalsSaved)));
  }

  @override
  Widget build(BuildContext context) {
    return NurseScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context.l10n.nurseVitalsRecording),
          _PatientBanner(label: widget.patientLabel),
          const SizedBox(height: 12),
          TextField(controller: _bp, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseBloodPressure)),
          TextField(controller: _temp, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseTemperature)),
          TextField(controller: _weight, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseWeightKg)),
          TextField(controller: _height, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseHeightCm)),
          TextField(controller: _pulse, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nursePulse)),
          TextField(controller: _o2, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseOxygen)),
          TextField(controller: _sugar, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseBloodSugar)),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
            onPressed: _save,
            child: Text(context.l10n.nurseSaveVitals),
          ),
          const SizedBox(height: 20),
          Text(context.l10n.nurseTimeline, style: GoogleFonts.poppins(color: _kGold, fontWeight: FontWeight.w600)),
          ..._timeline.reversed.take(15).map((v) {
            final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
            return Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                tileColor: Colors.transparent,
                title: Text('BP ${m['bloodPressure'] ?? '—'} · Temp ${m['temperature'] ?? '—'}', style: const TextStyle(color: Colors.white)),
                subtitle: Text('${m['createdAt'] ?? ''}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class NurseNotesTab extends StatefulWidget {
  const NurseNotesTab({super.key, required this.api, this.patientId, this.patientLabel = ''});
  final NursePortalApi api;
  final String? patientId;
  final String patientLabel;
  @override
  State<NurseNotesTab> createState() => _NurseNotesTabState();
}

class _NurseNotesTabState extends State<NurseNotesTab> {
  final _body = TextEditingController();
  String _type = 'observation';
  bool _urgent = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pid = widget.patientId;
    if (pid == null || pid.isEmpty) return;
    await widget.api.post('/notes', {
      'patientUserId': pid,
      'noteType': _type,
      'body': _body.text.trim(),
      'urgentForDoctor': _urgent,
    });
    _body.clear();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.nurseNoteSaved)));
  }

  @override
  Widget build(BuildContext context) {
    return NurseScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context.l10n.nurseClinicalNotes),
          _PatientBanner(label: widget.patientLabel),
          DropdownButtonFormField<String>(
            value: _type,
            dropdownColor: const Color(0xFF1A2220),
            style: const TextStyle(color: Colors.white),
            decoration: _dec(context.l10n.nurseNoteType),
            items: [
              DropdownMenuItem(value: 'observation', child: Text(context.l10n.nurseNoteObservation)),
              DropdownMenuItem(value: 'shift_log', child: Text(context.l10n.nurseNoteShiftLog)),
              DropdownMenuItem(value: 'doctor_alert', child: Text(context.l10n.nurseNoteDoctorAlert)),
              DropdownMenuItem(value: 'initial_symptoms', child: Text(context.l10n.nurseNoteInitialSymptoms)),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'observation'),
          ),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              tileColor: Colors.transparent,
              value: _urgent,
              onChanged: (v) => setState(() => _urgent = v),
              title: Text(context.l10n.nurseUrgentForDoctor, style: const TextStyle(color: Colors.white)),
              activeThumbColor: _kGold,
            ),
          ),
          TextField(controller: _body, maxLines: 5, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseNote)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
            onPressed: _save,
            child: Text(context.l10n.nurseSaveNote),
          ),
        ],
      ),
    );
  }
}

class NurseMedicationsTab extends StatefulWidget {
  const NurseMedicationsTab({super.key, required this.api, this.patientId, this.patientLabel = ''});
  final NursePortalApi api;
  final String? patientId;
  final String patientLabel;
  @override
  State<NurseMedicationsTab> createState() => _NurseMedicationsTabState();
}

class _NurseMedicationsTabState extends State<NurseMedicationsTab> {
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _reaction = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _reaction.dispose();
    super.dispose();
  }

  Future<void> _log() async {
    final pid = widget.patientId;
    if (pid == null || pid.isEmpty) return;
    await widget.api.post('/medications/log', {
      'patientUserId': pid,
      'medicationName': _name.text.trim(),
      'dosage': _dose.text.trim(),
      if (_reaction.text.isNotEmpty) 'adverseReaction': _reaction.text.trim(),
    });
    _name.clear();
    _dose.clear();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.nurseDoseLogged)));
  }

  @override
  Widget build(BuildContext context) {
    return NurseScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context.l10n.nurseMedicationTreatment),
          _PatientBanner(label: widget.patientLabel),
          TextField(controller: _name, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseMedication)),
          TextField(controller: _dose, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseDosage)),
          TextField(controller: _reaction, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseAdverseReaction)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
            onPressed: _log,
            child: Text(context.l10n.nurseLogAdministration),
          ),
        ],
      ),
    );
  }
}

class NurseLabsTab extends StatefulWidget {
  const NurseLabsTab({super.key, required this.api, this.patientId, this.patientLabel = ''});
  final NursePortalApi api;
  final String? patientId;
  final String patientLabel;
  @override
  State<NurseLabsTab> createState() => _NurseLabsTabState();
}

class _NurseLabsTabState extends State<NurseLabsTab> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  final Set<String> _expandedIds = {};
  final Set<String> _submittingIds = {};
  final Map<String, LabResultFormHolder> _resultForms = {};
  final Map<String, GlobalKey<FormState>> _formKeys = {};

  @override
  void initState() {
    super.initState();
    _loadIncoming();
  }

  @override
  void dispose() {
    for (final f in _resultForms.values) {
      f.dispose();
    }
    super.dispose();
  }

  LabResultFormHolder _resultFormFor(String orderId) {
    return _resultForms.putIfAbsent(orderId, LabResultFormHolder.new);
  }

  GlobalKey<FormState> _formKeyFor(String orderId) {
    return _formKeys.putIfAbsent(orderId, GlobalKey<FormState>.new);
  }

  void _disposeResultForm(String orderId) {
    _resultForms.remove(orderId)?.dispose();
    _formKeys.remove(orderId);
  }

  Widget _buildDynamicResultForm(String orderId, String testType) {
    return LabResultDynamicForm(
      testType: testType,
      holder: _resultFormFor(orderId),
      onChanged: () => setState(() {}),
    );
  }

  Future<void> _loadIncoming() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.incomingLabRequests();
      if (!mounted) return;
      final mapped = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) {
            final s = e['status']?.toString() ?? '';
            return s == 'Requested' ||
                s == 'Pending' ||
                s == 'Sample-Collected' ||
                s == 'Scheduled';
          })
          .toList();
      setState(() {
        _orders = mapped;
        _error = null;
        final liveIds = mapped.map((e) => e['_id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
        _expandedIds.removeWhere((id) => !liveIds.contains(id));
        for (final id in _resultForms.keys.toList()) {
          if (!liveIds.contains(id)) _disposeResultForm(id);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _orders = [];
          _error = nurseFriendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitReport(Map<String, dynamic> order) async {
    final orderId = order['_id']?.toString() ?? '';
    if (orderId.isEmpty || _submittingIds.contains(orderId)) return;
    final formKey = _formKeyFor(orderId);
    if (!(formKey.currentState?.validate() ?? false)) return;

    final testType = normalizeLabTestType(order['testType']?.toString() ?? 'Blood');
    final holder = _resultFormFor(orderId);
    if (!holder.hasMinimumData(testType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.nurseEnterResultBeforeSubmit),
          backgroundColor: const Color(0xFF1A1510),
        ),
      );
      return;
    }

    final resultJson = holder.toJson(testType);

    setState(() => _submittingIds.add(orderId));
    try {
      await widget.api.submitLabReport(orderId, {
        'resultAnalysis': resultJson,
        'results': resultJson,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.nurseReportSubmitted),
          backgroundColor: const Color(0xFF1A1510),
        ),
      );
      setState(() {
        _expandedIds.remove(orderId);
        _disposeResultForm(orderId);
      });
      await _loadIncoming();
    } catch (e) {
      if (mounted) _showNurseSnack(context, e);
    } finally {
      if (mounted) setState(() => _submittingIds.remove(orderId));
    }
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kGold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kGold.withValues(alpha: 0.65)),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(color: _kGoldLight, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final orderId = order['_id']?.toString() ?? '';
    final patientUserId = order['patientUserId']?.toString() ?? '—';
    final testName = order['testName']?.toString() ?? '—';
    final testType = normalizeLabTestType(order['testType']?.toString() ?? 'Blood');
    final status = order['status']?.toString() ?? 'Requested';
    final expanded = _expandedIds.contains(orderId);
    final submitting = _submittingIds.contains(orderId);
    final patient = order['patient'] is Map
        ? Map<String, dynamic>.from(order['patient'] as Map)
        : <String, dynamic>{};
    final patientName = patient['fullName']?.toString();

    return Card(
      color: _kGlass,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _kGold.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.biotech_outlined, color: _kGold, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (patientName != null && patientName.isNotEmpty)
                        Text(
                          patientName,
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.nursePatientId(patientUserId),
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.nurseTestLabel(testName, testType),
                        style: GoogleFonts.poppins(color: _kGoldLight, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 14),
            if (!expanded)
              Material(
                color: Colors.transparent,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kGoldLight,
                    side: BorderSide(color: _kGold.withValues(alpha: 0.65)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => setState(() => _expandedIds.add(orderId)),
                  icon: const Icon(Icons.edit_note_outlined, color: _kGold, size: 20),
                  label: Text(context.l10n.nurseEnterResults),
                ),
              )
            else
              Form(
                key: _formKeyFor(orderId),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kGold.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        context.l10n.nurseResultEntry(testType),
                        style: GoogleFonts.poppins(color: _kGoldLight, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDynamicResultForm(orderId, testType),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
                            onPressed: submitting ? null : () => _submitReport(order),
                            child: submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                  )
                                : Text(context.l10n.nurseSubmitReport),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kGoldLight,
                            side: BorderSide(color: _kGold.withValues(alpha: 0.55)),
                          ),
                          onPressed: submitting
                              ? null
                              : () => setState(() {
                                    _expandedIds.remove(orderId);
                                    _disposeResultForm(orderId);
                                  }),
                          child: Text(context.l10n.nurseCancel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NurseScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context.l10n.nurseIncomingLabOrders),
          Text(
            context.l10n.nurseLabOrdersHint,
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
                onPressed: _loading ? null : _loadIncoming,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(_orders.isEmpty ? context.l10n.nurseLoadOrders : context.l10n.nurseRefresh),
              ),
              const SizedBox(width: 12),
              if (_orders.isNotEmpty)
                Text(
                  context.l10n.nursePendingCount(_orders.length),
                  style: GoogleFonts.poppins(color: _kGoldLight, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
              ),
              child: Text(_error!, style: GoogleFonts.poppins(color: Colors.redAccent.shade100, fontSize: 13)),
            ),
          if (_loading && _orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(color: _kGold)),
            )
          else if (!_loading && _orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                context.l10n.nurseNoIncomingLabOrders,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
              ),
            )
          else
            ..._orders.map(_orderCard),
        ],
      ),
    );
  }
}

class NurseAlertsTab extends StatefulWidget {
  const NurseAlertsTab({super.key, required this.api, this.patientId, this.patientLabel = ''});
  final NursePortalApi api;
  final String? patientId;
  final String patientLabel;
  @override
  State<NurseAlertsTab> createState() => _NurseAlertsTabState();
}

class _NurseAlertsTabState extends State<NurseAlertsTab> {
  final _alertTitle = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _alertTitle.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _dispatch() async {
    final pid = widget.patientId;
    if (pid == null || pid.isEmpty) return;
    try {
      await widget.api.post('/alerts/dispatch', {
        'patientUserId': pid,
        'title': _alertTitle.text.trim(),
        'body': _body.text.trim(),
        'channel': 'push',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.nurseAlertDispatched)),
        );
      }
    } catch (e) {
      if (mounted) _showNurseSnack(context, e, quiet: nurseIsPermissionDenied(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return NurseScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context.l10n.nursePrintsAlerts),
          _PatientBanner(label: widget.patientLabel),
          TextField(controller: _alertTitle, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseAlertTitle)),
          TextField(controller: _body, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseMessageBody)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
            onPressed: _dispatch,
            child: Text(context.l10n.nurseSendNotification),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.nursePrintBrowserHint))),
            icon: const Icon(Icons.print, color: _kGold),
            label: Text(context.l10n.nursePrintShiftReference, style: const TextStyle(color: _kGold)),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyContractTile extends StatelessWidget {
  const _ReadOnlyContractTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: _kGold.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile & HR contract hub — editable account + read-only admin assignment.
class NurseProfileTab extends StatefulWidget {
  const NurseProfileTab({super.key, required this.api, required this.nurseUserId, this.nurseName});
  final NursePortalApi api;
  final String nurseUserId;
  final String? nurseName;
  @override
  State<NurseProfileTab> createState() => _NurseProfileTabState();
}

class _NurseProfileTabState extends State<NurseProfileTab> {
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _contract;

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pwdCurrent = TextEditingController();
  final _pwdNew = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _pwdCurrent.dispose();
    _pwdNew.dispose();
    super.dispose();
  }

  void _applyProfileData(Map<String, dynamic> data) {
    final account = data['account'] is Map ? Map<String, dynamic>.from(data['account'] as Map) : <String, dynamic>{};
    final user = data['user'] is Map ? Map<String, dynamic>.from(data['user'] as Map) : <String, dynamic>{};
    _fullName.text = account['fullName']?.toString() ?? user['name']?.toString() ?? widget.nurseName ?? '';
    _email.text = account['email']?.toString() ?? user['email']?.toString() ?? '';
    _phone.text = account['phone']?.toString() ?? user['phoneNumber']?.toString() ?? '';
    _contract = data['contract'] is Map ? Map<String, dynamic>.from(data['contract'] as Map) : {};
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.get('/profile');
      if (!mounted) return;
      setState(() {
        _applyProfileData(Map<String, dynamic>.from(data as Map));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showNurseSnack(context, e);
    }
  }

  Future<void> _save() async {
    final newPwd = _pwdNew.text.trim();
    final curPwd = _pwdCurrent.text;
    if (newPwd.isNotEmpty && newPwd.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.nursePasswordMinLength)),
      );
      return;
    }
    if (newPwd.isNotEmpty && curPwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.nurseCurrentPasswordRequired)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'fullName': _fullName.text.trim(),
        'email': _email.text.trim(),
        'phoneNumber': _phone.text.trim(),
      };
      if (newPwd.isNotEmpty) {
        body['currentPassword'] = curPwd;
        body['newPassword'] = newPwd;
      }
      final res = await widget.api.putAuthProfileUpdate(body);
      if (!mounted) return;
      _applyProfileData(Map<String, dynamic>.from(res as Map));
      _pwdCurrent.clear();
      _pwdNew.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.nurseAccountSaved)),
      );
    } catch (e) {
      if (mounted) _showNurseSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kGold));
    }

    final c = _contract ?? {};

    return NurseScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context.l10n.nurseProfileHr),
          Text(
            context.l10n.nurseProfileHint,
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Card(
            color: _kGlass,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: _kGold.withValues(alpha: 0.65)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.l10n.nurseAccountSettings, style: GoogleFonts.poppins(color: _kGold, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 14),
                  TextField(controller: _fullName, style: const TextStyle(color: Colors.white), decoration: _dec(context.l10n.nurseFullName)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec(context.l10n.nurseEmail, icon: Icons.mail_outline),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec(context.l10n.nursePhoneNumber, icon: Icons.phone_outlined),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.nurseChangePasswordOptional,
                    style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pwdCurrent,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec(context.l10n.nurseCurrentPassword, icon: Icons.lock_outline),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pwdNew,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec(context.l10n.nurseNewPassword, icon: Icons.lock_reset_outlined),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? context.l10n.nurseSaving : context.l10n.nurseSaveChanges,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: _kGlass,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _kGold, width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, color: _kGold, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.nurseAdminContract,
                          style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _kGold.withValues(alpha: 0.5)),
                        ),
                        child: Text(context.l10n.nurseReadOnly, style: const TextStyle(color: _kGold, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.nurseContractReadOnlyHint,
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  _ReadOnlyContractTile(
                    label: context.l10n.nurseAssignedDepartment,
                    value: c['departmentName']?.toString() ?? context.l10n.nurseNotAssigned,
                  ),
                  _ReadOnlyContractTile(
                    label: context.l10n.nurseShiftTimings,
                    value: c['shiftTimings']?.toString() ?? '—',
                  ),
                  _ReadOnlyContractTile(
                    label: context.l10n.nurseWorkingDays,
                    value: c['workingDays']?.toString() ?? '—',
                  ),
                  _ReadOnlyContractTile(
                    label: context.l10n.nurseMonthlySalary,
                    value: c['monthlySalaryLabel']?.toString() ?? context.l10n.nursePendingAdminAssignment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
