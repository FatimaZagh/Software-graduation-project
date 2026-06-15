import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../api_config.dart';
import '../../../widgets/looping_asset_video_background.dart' show kHospitalBackgroundVideoAsset;
import '../data/patient_portal_api.dart';
import 'patient_appointments_screen.dart';
import 'patient_emergency_screen.dart';
import 'patient_my_medications_screen.dart';
import 'book_appointment_dialog.dart';
import 'patient_home_video_bridge.dart';
import 'patient_theme.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({
    super.key,
    required this.patientUserId,
    this.embedMode = false,
  });

  final String patientUserId;
  final bool embedMode;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _profile;
  List<dynamic> _upcoming = [];
  List<dynamic> _past = [];
  List<Map<String, dynamic>> _stoppedMedAlerts = [];
  List<Map<String, dynamic>> _erRedirectAlerts = [];
  bool _loading = true;
  String? _loadError;
  final Set<String> _dismissedCancelledIds = {};
  final Map<String, bool> _erAlertUrgentById = {};
  final Set<String> _erAlertHiddenIds = {};
  Timer? _stoppedAlertPoll;
  static const String _kErHomeBannerMessage = 'Go to the nearest medical center';

  late final Player _player;
  late final VideoController _playerController;
  bool _videoReady = false;
  bool _videoSurfaceVisible = true;
  bool _wasPlayingBeforePause = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _playerController = VideoController(_player);
    PatientHomeVideoBridge.instance.register(
      pause: _pauseBackgroundVideo,
      resume: _resumeBackgroundVideo,
    );
    _initBackgroundVideo();
    _loadDashboard();
    _stoppedAlertPoll = Timer.periodic(const Duration(seconds: 12), (_) => _refreshCriticalAlerts());
  }

  Future<void> _initBackgroundVideo() async {
    try {
      await _player.setPlaylistMode(PlaylistMode.loop);
      await _player.setVolume(0);
      await _player.open(Media('asset:///$kHospitalBackgroundVideoAsset'));
      if (mounted) setState(() => _videoReady = true);
    } catch (_) {
      if (mounted) setState(() => _videoReady = false);
    }
  }

  Future<void> _pauseBackgroundVideo() async {
    if (!_videoReady) return;
    _wasPlayingBeforePause = _player.state.playing;
    if (mounted && _videoSurfaceVisible) {
      setState(() => _videoSurfaceVisible = false);
    }
    if (_wasPlayingBeforePause) {
      await _player.pause();
    }
    // Let Windows release the hardware video surface before overlays / pickers open.
    await Future<void>.delayed(const Duration(milliseconds: 48));
  }

  Future<void> _resumeBackgroundVideo() async {
    if (!_videoReady) return;
    if (_wasPlayingBeforePause) {
      await _player.play();
    }
    if (mounted && !_videoSurfaceVisible) {
      setState(() => _videoSurfaceVisible = true);
    }
  }

  Future<T?> _withPausedVideo<T>(Future<T?> Function() action) {
    return PatientHomeVideoBridge.instance.runWithPausedOverlay(action);
  }

  @override
  void dispose() {
    PatientHomeVideoBridge.instance.unregister();
    _stoppedAlertPoll?.cancel();
    _player.dispose();
    super.dispose();
  }


  List<Map<String, dynamic>> _parseErRedirectNotifications(List<dynamic> notifications) {
    return [
      for (final raw in notifications)
        if (raw is Map)
          if (Map<String, dynamic>.from(raw)['type']?.toString() == 'er_redirect' &&
              Map<String, dynamic>.from(raw)['read'] != true)
            Map<String, dynamic>.from(raw),
    ];
  }

  Future<void> _refreshCriticalAlerts() async {
    if (_loading) return;
    try {
      final results = await Future.wait([
        http
            .get(Uri.parse('$rafeeqApiBase/api/patients/${widget.patientUserId}/stopped-medication-alerts'))
            .timeout(const Duration(seconds: 12)),
        PatientPortalApi.getNotifications(widget.patientUserId),
      ]);
      if (!mounted) return;
      List<Map<String, dynamic>> stopped = _stoppedMedAlerts;
      if (results[0] is http.Response && (results[0] as http.Response).statusCode == 200) {
        final raw = jsonDecode((results[0] as http.Response).body);
        if (raw is List) {
          stopped = [
            for (final e in raw)
              if (e is Map) Map<String, dynamic>.from(e as Map),
          ];
        }
      }
      final erAlerts = _parseErRedirectNotifications(results[1] as List<dynamic>);
      setState(() {
        _stoppedMedAlerts = stopped;
        _erRedirectAlerts = erAlerts;
      });
    } catch (_) {}
  }

  String get _displayName =>
      _profile?['fullName']?.toString() ?? _profile?['email']?.toString() ?? 'Patient';

  Map<String, dynamic>? get _rescheduleVisit {
    for (final raw in _upcoming) {
      final m = Map<String, dynamic>.from(raw as Map);
      if (m['bookingStatus']?.toString() == 'reschedule_requested') return m;
    }
    return null;
  }

  List<Map<String, dynamic>> get _doctorCancelledVisits {
    final out = <Map<String, dynamic>>[];
    for (final raw in _upcoming) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      if (m['status']?.toString() != 'cancelled_by_doctor') continue;
      final id = m['_id']?.toString() ?? '';
      if (id.isEmpty || _dismissedCancelledIds.contains(id)) continue;
      if (m['cancelAlertDismissed'] == true) continue;
      out.add(m);
    }
    return out;
  }

  Future<void> _dismissDoctorCancelAlert(Map<String, dynamic> appt) async {
    final id = appt['_id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _dismissedCancelledIds.add(id));
    try {
      await http
          .patch(
            Uri.parse('$rafeeqApiBase/api/appointments/$id/dismiss-cancel-alert'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'patientUserId': widget.patientUserId}),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // Card already hidden locally; server sync on next refresh.
    }
  }

  void _onRescheduleAfterDoctorCancel(Map<String, dynamic> appt) {
    _dismissDoctorCancelAlert(appt);
    _openBookDialog(
      initialDoctorUserId: appt['doctorUserId']?.toString(),
      initialDoctorName: appt['doctorName']?.toString(),
      initialClinicId: appt['clinicId']?.toString(),
    );
  }

  static const _reasonAr = {
    'Emergency': 'حالة طارئة',
    'Sick Leave': 'إجازة مرضية',
    'Surgery': 'عملية جراحية',
    'Equipment Issue': 'عطل في المعدات',
    'Other': 'سبب آخر',
  };

  String _reasonLabelAr(Map<String, dynamic> appt) {
    final r = appt['cancellationReason']?.toString() ?? 'Other';
    return _reasonAr[r] ?? r;
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        http.get(Uri.parse('$rafeeqApiBase/api/patients/${widget.patientUserId}')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('$rafeeqApiBase/api/patients/${widget.patientUserId}/appointments')).timeout(const Duration(seconds: 15)),
        http
            .get(Uri.parse('$rafeeqApiBase/api/patients/${widget.patientUserId}/stopped-medication-alerts'))
            .timeout(const Duration(seconds: 15)),
        PatientPortalApi.getNotifications(widget.patientUserId),
      ]);
      final profileRes = results[0] as http.Response;
      final apptRes = results[1] as http.Response;
      final stoppedRes = results[2] as http.Response;
      if (profileRes.statusCode != 200) throw Exception('Profile failed');
      if (apptRes.statusCode != 200) throw Exception('Appointments failed');
      final profile = jsonDecode(profileRes.body) as Map<String, dynamic>;
      final apptJson = jsonDecode(apptRes.body) as Map<String, dynamic>;
      List<Map<String, dynamic>> stoppedAlerts = [];
      if (stoppedRes.statusCode == 200) {
        final raw = jsonDecode(stoppedRes.body);
        if (raw is List) {
          stoppedAlerts = [
            for (final e in raw)
              if (e is Map) Map<String, dynamic>.from(e as Map),
          ];
        }
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _upcoming = (apptJson['upcoming'] as List<dynamic>?) ?? [];
        _past = (apptJson['past'] as List<dynamic>?) ?? [];
        _stoppedMedAlerts = stoppedAlerts;
        _erRedirectAlerts = _parseErRedirectNotifications(results[3] as List<dynamic>);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _bookAppointment(
    String date,
    String time,
    String doctor,
    String? clinicId,
    String branch,
    String? doctorUserId,
  ) async {
    try {
      final body = <String, dynamic>{
        'patientUserId': widget.patientUserId,
        'patientName': _displayName,
        'time': time.trim(),
        'date': date.trim(),
        if (doctor.trim().isNotEmpty) 'doctorName': doctor.trim(),
        if (doctorUserId != null && doctorUserId.isNotEmpty) 'doctorUserId': doctorUserId,
        if (branch.trim().isNotEmpty) 'branch': branch.trim(),
        if (clinicId != null && clinicId.isNotEmpty) 'clinicId': clinicId,
      };
      final res = await http
          .post(
            Uri.parse('$rafeeqApiBase/api/appointments/book'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 201 || res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['addedToWaitingList'] == true) {
          final msg = decoded['message']?.toString().trim();
          _showSnack(
            msg != null && msg.isNotEmpty
                ? msg
                : 'Slot full — you have been added to the waiting list.',
          );
        } else {
          _showSnack('Appointment booked');
        }
        await _loadDashboard();
      } else {
        _showSnack(_parseBookingMessage(res.body));
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Connection failed');
    }
  }

  Future<void> _openBookDialog({
    Map<String, dynamic>? rescheduleAppt,
    String? initialDoctorUserId,
    String? initialDoctorName,
    String? initialClinicId,
  }) async {
    final r = rescheduleAppt;
    await _withPausedVideo(() {
      return showBookAppointmentDialog(
        context,
        patientUserId: widget.patientUserId,
        patientName: _displayName,
        defaultBranch: _profile?['defaultBranch']?.toString() ?? '',
        rescheduleAppointmentId: r?['_id']?.toString(),
        initialDoctorUserId: initialDoctorUserId ?? r?['doctorUserId']?.toString(),
        initialDoctorName: initialDoctorName ?? r?['doctorName']?.toString(),
        initialClinicId: initialClinicId ?? r?['clinicId']?.toString(),
        onBook: (date, time, doctor, clinicId, branch, doctorUserId) async {
          await _loadDashboard();
        },
      );
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: kPatientSheetBg),
    );
  }

  String _erAlertId(Map<String, dynamic> alert) => alert['_id']?.toString() ?? '';

  bool _isErAlertVisible(String alertId) =>
      alertId.isNotEmpty && !_erAlertHiddenIds.contains(alertId);

  bool _isErAlertUrgent(String alertId) => _erAlertUrgentById[alertId] ?? true;

  void _softAcknowledgeErAlert(String alertId) {
    if (alertId.isEmpty) return;
    setState(() => _erAlertUrgentById[alertId] = false);
  }

  Future<void> _dismissErRedirectAlert(Map<String, dynamic> alert) async {
    final alertId = _erAlertId(alert);
    if (alertId.isEmpty) return;
    setState(() => _erAlertHiddenIds.add(alertId));
    try {
      await PatientPortalApi.markNotificationRead(widget.patientUserId, alertId);
    } catch (_) {
      await _loadDashboard();
    }
  }

  Widget _erRedirectBanner(Map<String, dynamic> alert) {
    final alertId = _erAlertId(alert);
    final isUrgent = _isErAlertUrgent(alertId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFF3A1212) : kPatientFieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUrgent ? Colors.redAccent.shade200 : kPatientGold.withValues(alpha: 0.45),
          width: isUrgent ? 2.5 : 1,
        ),
        boxShadow: isUrgent
            ? [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_hospital,
            color: isUrgent ? Colors.redAccent.shade100 : kPatientGoldLight,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _softAcknowledgeErAlert(alertId),
              behavior: HitTestBehavior.opaque,
              child: Text(
                _kErHomeBannerMessage,
                style: GoogleFonts.urbanist(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: () => _dismissErRedirectAlert(alert),
            icon: Icon(
              Icons.close,
              color: isUrgent ? Colors.redAccent.shade100 : Colors.white54,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acknowledgeStoppedMedAlert(Map<String, dynamic> alert) async {
    final alertId = alert['_id']?.toString() ?? '';
    if (alertId.isEmpty) return;
    setState(() {
      _stoppedMedAlerts = _stoppedMedAlerts.where((a) => a['_id']?.toString() != alertId).toList();
    });
    try {
      await http
          .post(
            Uri.parse(
              '$rafeeqApiBase/api/patients/${widget.patientUserId}/stopped-medication-alerts/$alertId/acknowledge',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      await _loadDashboard();
    }
  }

  Widget _stoppedMedicationBanner(Map<String, dynamic> alert) {
    final medName = alert['medicationName']?.toString() ?? 'الدواء';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚠️ تم إيقاف دواء $medName بواسطة الطبيب المتابع لحالتك. يرجى الامتناع عن أخذ أي جرعات إضافية فوراً والالتزام بالتعليمات الطبية.',
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => _acknowledgeStoppedMedAlert(alert),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Dismiss / قرأت وفهمت',
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _parseBookingMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) return decoded['message'].toString();
    } catch (_) {}
    return body.trim().isEmpty ? 'Booking failed' : body;
  }

  Widget _doctorCancelledBanner(Map<String, dynamic> appt, bool isAr) {
    final reasonAr = _reasonLabelAr(appt);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1212),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.9), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAr ? 'تنبيه إلغاء' : 'Cancellation alert',
                  style: GoogleFonts.urbanist(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'تم إلغاء الموعد من قِبل الطبيب لحالة طارئة ($reasonAr). يرجى إعادة حجز موعد آخر من المواعيد المتاحة.',
            style: GoogleFonts.urbanist(color: Colors.white, height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '${appt['doctorName'] ?? ''} · ${appt['date'] ?? ''} ${appt['time'] ?? ''}',
            style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _onRescheduleAfterDoctorCancel(appt),
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: [kPatientGoldLight, kPatientGold]),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'إعادة حجز موعد',
                    style: GoogleFonts.urbanist(color: kPatientWorkspaceBlack, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rescheduleBanner(bool isAr) {
    final r = _rescheduleVisit!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAr ? 'تنبيه موعد' : 'Appointment alert',
                  style: GoogleFonts.urbanist(color: kPatientGoldLight, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isAr
                ? 'تم تأجيل الموعد من قِبل الطبيب لظرف طارئ، يرجى اختيار موعد حجز آخر مناسب لك.'
                : 'Your doctor postponed this visit due to an emergency. Please choose a new suitable time at no extra charge.',
            style: GoogleFonts.urbanist(color: Colors.white, height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '${r['doctorName'] ?? ''} · ${r['date'] ?? ''} ${r['time'] ?? ''}',
            style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openBookDialog(rescheduleAppt: r),
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(colors: [kPatientGoldLight, kPatientGold]),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    isAr ? 'اختر موعداً جديداً' : 'Select new date',
                    style: GoogleFonts.urbanist(color: kPatientWorkspaceBlack, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: kPatientFieldFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kPatientGold.withValues(alpha: 0.55)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 34, color: kPatientGoldLight),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final w = MediaQuery.sizeOf(context).width;
    final maxContent = w > 1200 ? 900.0 : w;
    // Wide: 3 columns so Book / My Bookings / My Medications share one row; Emergency wraps below.
    final crossAxisCount = w >= 700 ? 3 : 2;
    final reschedule = _rescheduleVisit;
    final doctorCancelled = _doctorCancelledVisits;

    final dashboardBody = LayoutBuilder(
      builder: (context, constraints) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator(color: kPatientGold));
        }
        if (_loadError != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadDashboard,
                    style: FilledButton.styleFrom(backgroundColor: kPatientGold, foregroundColor: kPatientWorkspaceBlack),
                    child: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContent),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: w < 400 ? 12 : 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final alert in _erRedirectAlerts)
                    if (_isErAlertVisible(_erAlertId(alert))) _erRedirectBanner(alert),
                  for (final alert in _stoppedMedAlerts) _stoppedMedicationBanner(alert),
                  if (reschedule != null) _rescheduleBanner(isAr),
                  for (final c in doctorCancelled) _doctorCancelledBanner(c, isAr),
                  Text(isAr ? 'إجراءات سريعة' : 'Quick actions', style: patientTitleStyle()),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: w >= 700 ? 1.2 : 0.95,
                    children: [
                      _actionCard(
                        title: isAr ? 'حجز موعد' : 'Book Appointment',
                        icon: Icons.calendar_month,
                        onTap: () => _openBookDialog(),
                      ),
                      _actionCard(
                        title: isAr ? 'حجوزاتي' : 'My Bookings',
                        icon: Icons.event_note,
                        onTap: () => _withPausedVideo(() {
                          return Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PatientAppointmentsScreen(patientUserId: widget.patientUserId),
                            ),
                          );
                        }),
                      ),
                      _actionCard(
                        title: isAr ? 'أدويتي' : 'My Medications',
                        icon: Icons.medication,
                        onTap: () async {
                          await _withPausedVideo(() {
                            return Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PatientMyMedicationsScreen(patientUserId: widget.patientUserId),
                              ),
                            );
                          });
                          if (mounted) _loadDashboard();
                        },
                      ),
                      _actionCard(
                        title: isAr ? 'طوارئ' : 'Emergency',
                        icon: Icons.phone_forwarded,
                        onTap: () => _withPausedVideo(() {
                          return Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PatientEmergencyScreen(patientUserId: widget.patientUserId),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  if (_past.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const SizedBox(height: 20),
                    Text(isAr ? 'زيارات سابقة (${_past.length})' : 'Past visits (${_past.length})',
                        style: patientTitleStyle(16)),
                    const SizedBox(height: 8),
                    ..._past.take(5).map((raw) {
                      final p = Map<String, dynamic>.from(raw as Map);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: kPatientFieldFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kPatientGold.withValues(alpha: 0.25)),
                        ),
                        child: ListTile(
                          title: Text(p['date']?.toString() ?? '—', style: patientBodyStyle()),
                          subtitle: Text(
                            '${p['time'] ?? ''} · ${p['status'] ?? ''}',
                            style: patientBodyStyle(color: Colors.white54, size: 12),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    final foreground = widget.embedMode
        ? dashboardBody
        : Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: kPatientGoldLight,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              title: Text(
                _loading ? (isAr ? 'مرحباً' : 'Welcome') : '${isAr ? 'مرحباً' : 'Welcome'}, $_displayName',
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w600, fontSize: w < 400 ? 16 : 18),
              ),
              actions: [
                if (!_loading)
                  IconButton(icon: const Icon(Icons.refresh, color: kPatientGoldLight), onPressed: _loadDashboard),
              ],
            ),
            body: dashboardBody,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_videoReady || !_videoSurfaceVisible)
          const ColoredBox(color: kPatientWorkspaceBlack)
        else
          Positioned.fill(
            child: IgnorePointer(
              child: Video(
                key: const ValueKey('patient_home_background_video'),
                controller: _playerController,
                fit: BoxFit.cover,
                fill: kPatientWorkspaceBlack,
                controls: NoVideoControls,
              ),
            ),
          ),
        Container(color: Colors.black.withValues(alpha: 0.5)),
        foreground,
      ],
    );
  }
}
