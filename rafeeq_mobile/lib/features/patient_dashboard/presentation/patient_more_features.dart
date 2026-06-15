import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../l10n/l10n_extensions.dart';
import '../data/medication_notification_service.dart';
import '../data/patient_navigation_bus.dart';
import '../data/patient_portal_api.dart';
import 'patient_appointments_screen.dart';
import 'patient_dispensing_prescriptions_screen.dart';
import 'patient_my_medications_screen.dart';
import 'patient_purchased_medications_screen.dart';
import 'patient_emergency_screen.dart';
import 'patient_theme.dart';
import '../../../api_config.dart';
import '../../../tenant_state.dart';
import '../../../utils/chat_message_helpers.dart';
import '../../../utils/chat_notification_helpers.dart';
import '../../../widgets/rafeeq_chat_bubble.dart';
import '../../diagnostic/data/diagnostic_api.dart';
import '../../diagnostic/presentation/lab_result_formatted_view.dart';
import 'rafeeq_ai_medical_assistant_screen.dart';

class PatientMoreHub extends StatelessWidget {
  const PatientMoreHub({super.key, required this.patientUserId});

  final String patientUserId;

  static bool _hasActiveClinicSession() => TenantState.instance.orgId.trim().isNotEmpty;

  void _showSessionNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.patientSessionRequired, style: patientBodyStyle(color: kPatientGoldLight, size: 13)),
        backgroundColor: const Color(0xFF1A2220),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: kPatientGold.withValues(alpha: 0.45)),
        ),
      ),
    );
  }

  void _openFeature(
    BuildContext context, {
    required VoidCallback navigate,
    bool warnIfNoSession = false,
  }) {
    if (warnIfNoSession && !_hasActiveClinicSession()) {
      _showSessionNotice(context);
    }
    navigate();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    // All 10 More-tab features — always visible regardless of clinic module flags.
    final tiles = <(IconData, String, VoidCallback, bool needsSessionHint)>[
      (
        Icons.chat_bubble_outlined,
        l10n.patientDoctorChat,
        () => push(PatientDoctorChatScreen(patientUserId: patientUserId)),
        false,
      ),
      (
        Icons.emergency_outlined,
        l10n.patientEmergency,
        () => push(PatientEmergencyScreen(patientUserId: patientUserId)),
        false,
      ),
      (
        Icons.event_note,
        l10n.patientMyBookings,
        () => push(PatientAppointmentsScreen(patientUserId: patientUserId)),
        false,
      ),
      (
        Icons.medication,
        l10n.patientMoreMyMedications,
        () => push(PatientMyMedicationsScreen(patientUserId: patientUserId)),
        false,
      ),
      (
        Icons.assignment,
        l10n.patientEPrescriptions,
        () => push(PatientDispensingPrescriptionsScreen(patientUserId: patientUserId)),
        false,
      ),
      (
        Icons.verified_outlined,
        l10n.patientMoreControlledRx,
        () => push(PatientDispensingPrescriptionsScreen(patientUserId: patientUserId)),
        false,
      ),
      (
        Icons.shopping_bag_outlined,
        l10n.patientMorePharmacyRequests,
        () => push(PatientPurchasedMedicationsScreen(patientUserId: patientUserId)),
        true,
      ),
      (
        Icons.biotech,
        l10n.patientMoreLabResults,
        () => push(PatientLabsScreen(patientUserId: patientUserId)),
        false,
      ),
      (
        Icons.smart_toy_outlined,
        context.isArabicLocale ? 'مساعد الصحة الذكي' : 'AI Health Assistant',
        () => push(RafeeqAiMedicalAssistantScreen(patientUserId: patientUserId)),
        false,
      ),
      (
        Icons.notifications_outlined,
        l10n.notifications,
        () => push(PatientNotificationsScreen(patientUserId: patientUserId)),
        false,
      ),
    ];

    const iconCyan = Color(0xFF26C6DA);

    return LayoutBuilder(
      builder: (context, c) {
        final cross = c.maxWidth > 700 ? 4 : 2;
        return SingleChildScrollView(
          child: Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: tiles.length,
                itemBuilder: (context, i) {
                  final t = tiles[i];
                  return Card(
                    color: kPatientFieldFill,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: kPatientGold.withValues(alpha: 0.22)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openFeature(
                        context,
                        navigate: t.$3,
                        warnIfNoSession: t.$4,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(t.$1, size: 36, color: iconCyan),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              t.$2,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: patientBodyStyle(color: Colors.white.withValues(alpha: 0.92), size: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}

class PatientDoctorChatScreen extends StatefulWidget {
  final String patientUserId;
  final String? initialDoctorUserId;
  final String? initialDoctorName;

  const PatientDoctorChatScreen({
    super.key,
    required this.patientUserId,
    this.initialDoctorUserId,
    this.initialDoctorName,
  });

  @override
  State<PatientDoctorChatScreen> createState() => _PatientDoctorChatScreenState();
}

class _PatientDoctorChatScreenState extends State<PatientDoctorChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _msgs = [];
  bool _loading = true;
  String? _loadError;
  List<dynamic> _clinics = [];
  List<dynamic> _doctors = [];
  String? _clinicId;
  String? _doctorUserId;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadClinics() async {
    final orgId = TenantState.instance.orgId;
    final r = await http.get(Uri.parse('$rafeeqApiBase/api/clinics?orgId=$orgId')).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    if (!mounted) return;
    setState(() => _clinics = list);
  }

  Future<void> _loadDoctors() async {
    final cid = _clinicId;
    if (cid == null) return;
    final d = await PatientPortalApi.getChatDoctors(widget.patientUserId, cid);
    if (!mounted) return;
    setState(() => _doctors = d);
  }

  Future<void> _load({bool silent = false}) async {
    final did = _doctorUserId;
    if (did == null) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final m = await PatientPortalApi.getChatMessages(widget.patientUserId, did);
      if (!mounted) return;
      setState(() {
        _msgs = m;
        _loading = false;
        _loadError = null;
      });
      if (_msgs.isNotEmpty) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    final did = _doctorUserId;
    if (did == null) return;
    _ctrl.clear();
    try {
      await PatientPortalApi.sendChat(widget.patientUserId, did, t);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void initState() {
    super.initState();
    () async {
      final presetDoctor = widget.initialDoctorUserId?.trim();
      if (presetDoctor != null && presetDoctor.isNotEmpty) {
        setState(() => _doctorUserId = presetDoctor);
        await _load();
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
        return;
      }

      try {
        await _loadClinics();
      } catch (_) {}
      if (_clinics.isNotEmpty) {
        final first = _clinics.first as Map<String, dynamic>;
        _clinicId = first['_id']?.toString();
        await _loadDoctors();
      }
      if (_doctors.isNotEmpty) {
        final first = _doctors.first as Map<String, dynamic>;
        _doctorUserId = first['userId']?.toString();
        await _load();
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const chatBg = Color(0xFF0B0B0C);
    return Scaffold(
      backgroundColor: chatBg,
      appBar: AppBar(
        title: Text(l10n.patientDoctorChat),
        backgroundColor: chatBg,
        foregroundColor: const Color(0xFFD4AF37),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _clinicId,
                    decoration: InputDecoration(border: const OutlineInputBorder(), labelText: l10n.patientClinic),
                    items: [
                      for (final raw in _clinics)
                        if (raw is Map && raw['_id'] != null)
                          DropdownMenuItem<String>(
                            value: raw['_id'].toString(),
                            child: Text(raw['name']?.toString() ?? ''),
                          ),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() {
                        _clinicId = v;
                        _doctorUserId = null;
                        _msgs = [];
                      });
                      await _loadDoctors();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _doctorUserId,
                    decoration: InputDecoration(border: const OutlineInputBorder(), labelText: l10n.doctor),
                    items: [
                      for (final raw in _doctors)
                        if (raw is Map && raw['userId'] != null)
                          DropdownMenuItem<String>(
                            value: raw['userId'].toString(),
                            child: Text(raw['name']?.toString() ?? ''),
                          ),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      _pollTimer?.cancel();
                      setState(() {
                        _doctorUserId = v;
                        _msgs = [];
                      });
                      await _load();
                      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _doctorUserId == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _doctors.isEmpty ? l10n.patientSelectClinicDoctor : l10n.patientSelectDoctorChat,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null && _msgs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_loadError!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: () => _load(), child: Text(l10n.retry)),
                            ],
                          ),
                        ),
                      )
                    : _msgs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                l10n.patientNoMessagesYet,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _msgs.length,
                            itemBuilder: (_, i) {
                              final m = _msgs[i];
                              return RafeeqChatBubble(
                                isMe: ChatMessageHelpers.isFromPatient(m, widget.patientUserId),
                                text: ChatMessageHelpers.bodyOf(m),
                                timestamp: ChatMessageHelpers.timestampOf(m),
                              );
                            },
                          ),
          ),
          Material(
            color: const Color(0xFF1A1A18),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        controller: _ctrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: l10n.patientMessageHint,
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.35),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: Color(0xFFD4AF37)),
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, color: Color(0xFFD4AF37)),
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

class PatientLabsScreen extends StatefulWidget {
  final String patientUserId;
  const PatientLabsScreen({super.key, required this.patientUserId});

  @override
  State<PatientLabsScreen> createState() => _PatientLabsScreenState();
}

class _PatientLabsScreenState extends State<PatientLabsScreen> {
  List<Map<String, dynamic>> _list = [];
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
      final l = await DiagnosticApi.patientResults(widget.patientUserId);
      if (mounted) setState(() => _list = l);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void openDiagnosticAttachment(
    BuildContext context, {
    required String url,
    String? fileName,
    String? mimeType,
  }) {
    if (url.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opening medical attachment/PDF...',
          style: patientBodyStyle(color: kPatientGoldLight, size: 13),
        ),
        backgroundColor: const Color(0xFF1A2220),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: kPatientGold.withValues(alpha: 0.45)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: kPatientWorkspaceBlack,
      appBar: AppBar(
        backgroundColor: kPatientWorkspaceBlack.withValues(alpha: 0.92),
        foregroundColor: kPatientGoldLight,
        title: Text(l10n.patientLabDiagnosticResults, style: patientTitleStyle(18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0F0D), Color(0xFF121816)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPatientGold))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center, style: patientBodyStyle(color: Colors.white70)),
                          const SizedBox(height: 16),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: kPatientGold, foregroundColor: kPatientWorkspaceBlack),
                            onPressed: _load,
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  )
                : _list.isEmpty
                    ? Center(child: Text(l10n.patientNoCompletedResults, style: patientBodyStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _list.length,
                        itemBuilder: (_, i) {
                          final m = _list[i];
                          final kind = m['kind']?.toString() ?? 'lab';
                          final testLabel = m['testOrModality']?.toString() ?? l10n.patientDiagnosticTest;
                          final modality = m['testType']?.toString() ?? '';
                          final attachmentUrl = m['attachmentUrl']?.toString() ?? '';
                          final patient = m['patient'] is Map
                              ? Map<String, dynamic>.from(m['patient'] as Map)
                              : <String, dynamic>{};
                          final ageGender = [
                            if (patient['age'] != null) l10n.patientYearsShort('${patient['age']}'),
                            if ((patient['gender']?.toString() ?? '').isNotEmpty) patient['gender'].toString(),
                          ].join(' · ');
                          return Card(
                            color: kPatientFieldFill,
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: kPatientGold.withValues(alpha: 0.55)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: kPatientGold.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: kPatientGold.withValues(alpha: 0.5)),
                                        ),
                                        child: Text(
                                          kind == 'radiology' ? l10n.patientRadiology : l10n.patientLaboratory,
                                          style: patientBodyStyle(color: kPatientGoldLight, size: 11),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(_formatDate(m['date']), style: patientBodyStyle(color: Colors.white54, size: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(testLabel, style: patientTitleStyle(16)),
                                  if (modality.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(modality, style: patientBodyStyle(color: Colors.white54, size: 13)),
                                    ),
                                  const SizedBox(height: 12),
                                  _resultRow(
                                    context,
                                    l10n.patientPatientId,
                                    patient['patientId']?.toString() ?? patient['id']?.toString() ?? widget.patientUserId,
                                  ),
                                  _resultRow(context, l10n.patientFullName, patient['fullName']?.toString() ?? l10n.patientEmDash),
                                  _resultRow(context, l10n.patientAgeGender, ageGender.isEmpty ? l10n.patientEmDash : ageGender),
                                  _resultRow(context, l10n.patientClinicLabel, _resolveClinicName(context, m)),
                                  _resultRow(
                                    context,
                                    l10n.patientDoctorLabel,
                                    m['doctorName']?.toString().trim().isNotEmpty == true ? m['doctorName'].toString() : l10n.patientEmDash,
                                  ),
                                  const Divider(color: Colors.white12, height: 22),
                                  _buildPatientResultBody(context, m, kind, modality),
                                  if (attachmentUrl.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: kPatientGoldLight,
                                          side: BorderSide(color: kPatientGold.withValues(alpha: 0.7)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                        onPressed: () => openDiagnosticAttachment(
                                          context,
                                          url: attachmentUrl,
                                          fileName: m['attachmentName']?.toString(),
                                          mimeType: m['mimeType']?.toString(),
                                        ),
                                        icon: const Icon(Icons.download_outlined, color: kPatientGold, size: 18),
                                        label: Text(
                                          m['attachmentName']?.toString() ?? l10n.patientDownloadViewFile,
                                          style: patientBodyStyle(color: kPatientGoldLight, size: 13),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildPatientResultBody(BuildContext context, Map<String, dynamic> m, String kind, String modality) {
    final l10n = context.l10n;
    final raw = m['resultAnalysis']?.toString();
    if (kind == 'radiology') {
      final parsed = LabResultFormattedView.tryParse(raw);
      if (parsed != null && (parsed['examType'] != null || parsed['bodyPartExamined'] != null)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_resultStr(parsed['examDateDisplay']).isNotEmpty)
              _resultRow(context, l10n.patientExamDate, _resultStr(parsed['examDateDisplay'])),
            if (_resultStr(parsed['examType']).isNotEmpty)
              _resultRow(context, l10n.patientExamType, _resultStr(parsed['examType'])),
            if (_resultStr(parsed['bodyPartExamined']).isNotEmpty)
              _resultRow(context, l10n.patientBodyPart, _resultStr(parsed['bodyPartExamined'])),
            if (_resultStr(parsed['technicianNotes']).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _resultStr(parsed['technicianNotes']),
                style: patientBodyStyle(color: Colors.white70, size: 14),
              ),
            ],
          ],
        );
      }
      final legacy = raw?.trim() ?? '';
      if (legacy.isEmpty) {
        return Text(l10n.patientNoAnalysisProvided, style: patientBodyStyle(color: Colors.white54, size: 14));
      }
      return Text(legacy, style: patientBodyStyle(color: Colors.white70, size: 14));
    }
    return LabResultFormattedView(
      resultAnalysis: raw,
      fallbackTestType: modality,
      accentColor: kPatientGold,
      accentLightColor: kPatientGoldLight,
    );
  }

  String _resultStr(dynamic v) => v == null ? '' : v.toString().trim();

  String _resolveClinicName(BuildContext context, Map<String, dynamic> m) {
    final direct = m['clinicName']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final clinic = m['clinicId'];
    if (clinic is Map) {
      final nested = clinic['name']?.toString().trim() ?? '';
      if (nested.isNotEmpty) return nested;
    }
    return context.l10n.patientPartnerMedicalCenter;
  }

  Widget _resultRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: patientBodyStyle(color: kPatientGold, size: 12))),
          Expanded(child: Text(value, style: patientBodyStyle(color: Colors.white70, size: 13))),
        ],
      ),
    );
  }
}

class PatientRatingScreen extends StatefulWidget {
  final String patientUserId;
  const PatientRatingScreen({super.key, required this.patientUserId});

  @override
  State<PatientRatingScreen> createState() => _PatientRatingScreenState();
}

class _PatientRatingScreenState extends State<PatientRatingScreen> {
  int _c = 5, _p = 5, _d = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.patientRateYourVisit), backgroundColor: Colors.teal.shade700),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.doctorCleanliness),
          Slider(value: _c.toDouble(), min: 1, max: 5, divisions: 4, label: '$_c', onChanged: (v) => setState(() => _c = v.round())),
          Text(l10n.doctorPunctuality),
          Slider(value: _p.toDouble(), min: 1, max: 5, divisions: 4, label: '$_p', onChanged: (v) => setState(() => _p = v.round())),
          Text(l10n.doctorBehavior),
          Slider(value: _d.toDouble(), min: 1, max: 5, divisions: 4, label: '$_d', onChanged: (v) => setState(() => _d = v.round())),
          TextField(controller: _comment, decoration: InputDecoration(labelText: l10n.doctorComment, border: const OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              try {
                await PatientPortalApi.postRating(
                  widget.patientUserId,
                  cleanliness: _c,
                  punctuality: _p,
                  doctorBehavior: _d,
                  comment: _comment.text,
                );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: Text(l10n.submit),
          ),
        ],
      ),
    );
  }
}

class PatientRemindersScreen extends StatefulWidget {
  final String patientUserId;
  const PatientRemindersScreen({super.key, required this.patientUserId});

  @override
  State<PatientRemindersScreen> createState() => _PatientRemindersScreenState();
}

class _PatientRemindersScreenState extends State<PatientRemindersScreen> {
  List<dynamic> _list = [];
  final _name = TextEditingController();
  final _times = TextEditingController(text: '08:00,20:00');

  @override
  void dispose() {
    _name.dispose();
    _times.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final l = await PatientPortalApi.getReminders(widget.patientUserId);
    if (!mounted) return;
    setState(() => _list = l);
    await MedicationNotificationService.syncFromReminderList(l);
  }

  @override
  void initState() {
    super.initState();
    MedicationNotificationService.ensureInitialized().then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.patientReminders), backgroundColor: Colors.teal.shade700),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                TextField(controller: _name, decoration: InputDecoration(labelText: l10n.patientMedicineName, border: const OutlineInputBorder())),
                TextField(controller: _times, decoration: InputDecoration(labelText: l10n.patientDoseTimes, border: const OutlineInputBorder())),
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await PatientPortalApi.postReminder(
                        widget.patientUserId,
                        _name.text.trim(),
                        _times.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                      );
                      _name.clear();
                      await _load();
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  child: Text(l10n.patientAdd),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _list.length,
              itemBuilder: (_, i) {
                final m = _list[i] as Map<String, dynamic>;
                final id = m['_id']?.toString() ?? '';
                return ListTile(
                  title: Text(m['medicineName']?.toString() ?? ''),
                  subtitle: Text((m['doseTimes'] as List<dynamic>? ?? []).join(', ')),
                    trailing: TextButton(
                    onPressed: id.isEmpty
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await PatientPortalApi.logDoseTaken(
                                widget.patientUserId,
                                id,
                                DateTime.now(),
                              );
                              await _load();
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(SnackBar(content: Text('$e')));
                            }
                          },
                    child: Text(l10n.patientMarkTaken),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              kIsWeb ? l10n.patientRemindersWebHint : l10n.patientRemindersDeviceHint,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientAnalyticsScreen extends StatefulWidget {
  final String patientUserId;
  const PatientAnalyticsScreen({super.key, required this.patientUserId});

  @override
  State<PatientAnalyticsScreen> createState() => _PatientAnalyticsScreenState();
}

class _PatientAnalyticsScreenState extends State<PatientAnalyticsScreen> {
  Map<String, dynamic>? _a;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await PatientPortalApi.getAnalytics(widget.patientUserId);
    if (mounted) setState(() => _a = a);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_a == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.patientYourAnalytics), backgroundColor: Colors.teal.shade700),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: Text(l10n.patientVisitCount), trailing: Text('${_a!['visitCount']}')),
          ListTile(title: Text(l10n.patientActiveMedicationReminders), trailing: Text('${_a!['activeMedicationReminders']}')),
          ListTile(title: Text(l10n.patientTotalPaymentsSar), trailing: Text('${_a!['totalPaymentsAmount']}')),
          ListTile(title: Text(l10n.patientLastCheckupLabel), subtitle: Text('${_a!['lastCheckupLabel'] ?? l10n.patientEmDash}')),
        ],
      ),
    );
  }
}

class PatientNotificationsScreen extends StatefulWidget {
  final String patientUserId;
  const PatientNotificationsScreen({super.key, required this.patientUserId});

  @override
  State<PatientNotificationsScreen> createState() => _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState extends State<PatientNotificationsScreen> {
  List<dynamic> _list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await PatientPortalApi.getNotifications(widget.patientUserId);
    if (mounted) setState(() => _list = l);
  }

  Future<void> _markRead(String id) async {
    await PatientPortalApi.markNotificationRead(widget.patientUserId, id);
    await _load();
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> m) async {
    final id = m['_id']?.toString() ?? '';

    if (ChatNotificationHelpers.isMessageNotification(m)) {
      final doctorUserId = ChatNotificationHelpers.doctorUserIdFromNotification(m);
      if (doctorUserId != null && doctorUserId.isNotEmpty) {
        if (id.isNotEmpty && m['read'] != true) {
          await PatientPortalApi.markNotificationRead(widget.patientUserId, id);
        }
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PatientDoctorChatScreen(
              patientUserId: widget.patientUserId,
              initialDoctorUserId: doctorUserId,
              initialDoctorName: ChatNotificationHelpers.peerDisplayName(m),
            ),
          ),
        );
        await _load();
        return;
      }
    }

    final intent = PatientNavigationIntent.fromNotification(m);

    if (intent != null) {
      if (id.isNotEmpty && m['read'] != true) {
        await PatientPortalApi.markNotificationRead(widget.patientUserId, id);
      }
      PatientNavigationBus.dispatch(intent);
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    if (id.isNotEmpty && m['read'] != true) {
      await _markRead(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: kPatientWorkspaceBlack,
      appBar: AppBar(
        title: Text(l10n.notifications, style: patientTitleStyle(17)),
        backgroundColor: kPatientWorkspaceBlack,
        foregroundColor: kPatientGold,
      ),
      body: ListView.builder(
        itemCount: _list.length,
        itemBuilder: (_, i) {
          final m = Map<String, dynamic>.from(_list[i] as Map);
          final isPartial = PatientNavigationIntent.isPartialFulfillmentNotification(m);
          final isMessage = ChatNotificationHelpers.isMessageNotification(m);
          final isErRedirect = m['type']?.toString() == 'er_redirect';
          final unread = m['read'] != true;
          final meta = m['meta'];
          final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
          final erMessage = metaMap['homeBannerMessage']?.toString().trim().isNotEmpty == true
              ? metaMap['homeBannerMessage'].toString()
              : l10n.patientGoNearestMedicalCenter;

          if (isErRedirect) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3A1212),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: unread ? Colors.redAccent.shade200 : Colors.redAccent.withValues(alpha: 0.35),
                  width: unread ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: Icon(Icons.local_hospital, color: Colors.redAccent.shade100, size: 28),
                title: Text(
                  erMessage,
                  textAlign: TextAlign.right,
                  style: patientBodyStyle().copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                subtitle: unread
                    ? Text(
                        l10n.patientErAlertFromDoctor,
                        style: patientBodyStyle(color: Colors.redAccent.shade100, size: 12),
                      )
                    : null,
                trailing: unread
                    ? const Icon(Icons.chevron_right, color: Colors.redAccent)
                    : const Icon(Icons.done, color: Colors.white38, size: 20),
                onTap: () => _handleNotificationTap(m),
              ),
            );
          }

          return ListTile(
            tileColor: unread ? kPatientFieldFill : null,
            leading: Icon(
              isMessage
                  ? Icons.chat_bubble_outline
                  : isPartial
                      ? Icons.inventory_2_outlined
                      : Icons.notifications_outlined,
              color: isMessage || isPartial ? kPatientGold : Colors.white54,
            ),
            title: Text(
              m['title']?.toString() ?? '',
              style: patientBodyStyle().copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
            ),
            subtitle: Text(
              m['body']?.toString() ?? '',
              style: patientBodyStyle(color: Colors.white54, size: 13),
            ),
            trailing: unread
                ? const Icon(Icons.chevron_right, color: kPatientGold)
                : const Icon(Icons.done, color: Colors.white38, size: 20),
            onTap: () => _handleNotificationTap(m),
          );
        },
      ),
    );
  }
}
