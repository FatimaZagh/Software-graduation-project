import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../landing_screen.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../tenant_state.dart';
import '../../../widgets/rafeeq_language_toggle.dart';
import '../../auth/presentation/auth_signup_theme.dart';
import '../../leave/leave_navigation.dart';
import '../data/diagnostic_api.dart';
import '../data/technician_session.dart';
import 'radiology_imaging_result_form.dart';

enum TechnicianDiagnosticKind { lab, radiology }

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kSidebar = Color(0xF00A1412);
const double _kBreakpoint = 900;

/// Technician workspace — incoming doctor orders, result entry, immutable submission.
class TechnicianDiagnosticShell extends StatefulWidget {
  const TechnicianDiagnosticShell({
    super.key,
    required this.userId,
    required this.kind,
    this.userName,
  });

  final String userId;
  final TechnicianDiagnosticKind kind;
  final String? userName;

  @override
  State<TechnicianDiagnosticShell> createState() => _TechnicianDiagnosticShellState();
}

class _TechnicianDiagnosticShellState extends State<TechnicianDiagnosticShell>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final DiagnosticApi _api = DiagnosticApi(userId: widget.userId);

  static const _incomingOrdersNavIndex = 1;

  int _navIndex = _incomingOrdersNavIndex;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _completed = [];
  bool _loading = true;
  bool _loadingCompleted = true;
  Timer? _poll;
  TabController? _orderTabs;

  final Map<String, GlobalKey<FormState>> _formKeys = {};
  final Map<String, TextEditingController> _analysisControllers = {};
  final Map<String, RadiologyImagingFormState> _radiologyForms = {};
  final Map<String, String?> _attachmentData = {};
  final Map<String, String> _attachmentLabels = {};
  final Set<String> _submittingIds = {};
  final Set<String> _expandedIds = {};

  String _technicianDisplayName = '';
  String _sessionRole = '';

  TechnicianDiagnosticKind get _effectiveKind {
    if (TechnicianSession.instance.isRadiologyRole || _sessionRole == 'Radiologist') {
      return TechnicianDiagnosticKind.radiology;
    }
    if (TechnicianSession.instance.isLabRole) {
      return TechnicianDiagnosticKind.lab;
    }
    return widget.kind;
  }

  bool get _isRadiology => _effectiveKind == TechnicianDiagnosticKind.radiology;

  String _roleTitle(BuildContext context) =>
      _isRadiology ? context.l10n.technicianRoleRadiologyTech : context.l10n.technicianRoleLabTechnician;

  int get _pendingBadgeCount => _pending.length;

  bool _isPendingStatus(String? status) {
    final s = (status ?? '').trim();
    if (s.isEmpty || s == 'Completed') return false;
    return s == 'Pending' ||
        s == 'Requested' ||
        s == 'Sample-Collected' ||
        s == 'Scheduled';
  }

  bool _matchesActiveDiscipline(Map<String, dynamic> order) {
    final hasImaging = (order['modality']?.toString().trim().isNotEmpty ?? false) ||
        (order['studyName']?.toString().trim().isNotEmpty ?? false);
    final hasLab = order['testName']?.toString().trim().isNotEmpty ?? false;
    if (_isRadiology) return hasImaging || (!hasLab && !hasImaging);
    return hasLab || (!hasLab && !hasImaging);
  }

  String _displayStatus(BuildContext context, String? raw) {
    final s = (raw ?? '').trim();
    if (s == 'Requested' || s == 'Sample-Collected' || s == 'Scheduled' || s.isEmpty) {
      return context.l10n.technicianStatusPending;
    }
    if (s == 'Completed') return context.l10n.technicianStatusCompleted;
    return s;
  }

  @override
  void initState() {
    super.initState();
    _technicianDisplayName = widget.userName ?? '';
    if (widget.kind == TechnicianDiagnosticKind.radiology) {
      _orderTabs = TabController(length: 2, vsync: this);
    }
    _loadIncomingRequests();
    if (_orderTabs != null) _loadCompletedExams();
    TechnicianSession.instance.load().then((_) {
      if (!mounted) return;
      final loadedRole = TechnicianSession.instance.role;
      setState(() {
        _sessionRole = loadedRole;
        if (_technicianDisplayName.isEmpty && TechnicianSession.instance.name.isNotEmpty) {
          _technicianDisplayName = TechnicianSession.instance.name;
        }
      });
      _loadIncomingRequests(silent: true);
      if (_orderTabs != null) _loadCompletedExams(silent: true);
    });
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadIncomingRequests(silent: true);
      if (_orderTabs != null) _loadCompletedExams(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _orderTabs?.dispose();
    for (final c in _analysisControllers.values) {
      c.dispose();
    }
    for (final f in _radiologyForms.values) {
      f.dispose();
    }
    super.dispose();
  }

  String _apiErrorMessage(Object e) {
    final s = e.toString();
    try {
      final start = s.indexOf('{');
      if (start >= 0) {
        final map = jsonDecode(s.substring(start)) as Map;
        final msg = map['message']?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return s.replaceFirst('Exception: ', '');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.urbanist(
            color: isError ? Colors.redAccent.shade100 : _kGoldLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF1A1510),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _kGold.withValues(alpha: isError ? 0.35 : 0.65)),
        ),
      ),
    );
  }

  Future<void> _loadIncomingRequests({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final list = _isRadiology
          ? await _api.pendingRadiology()
          : await _api.pendingForRole(
              _sessionRole.isNotEmpty ? _sessionRole : TechnicianSession.instance.role,
            );
      if (!mounted) return;
      final pendingOnly = list
          .where((e) => _isPendingStatus(e['status']?.toString()))
          .where(_matchesActiveDiscipline)
          .toList();
      setState(() {
        _pending = pendingOnly;
        final liveIds = pendingOnly.map((e) => e['_id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
        _expandedIds.removeWhere((id) => !liveIds.contains(id));
        for (final id in _analysisControllers.keys.toList()) {
          if (!liveIds.contains(id)) {
            _analysisControllers[id]?.dispose();
            _analysisControllers.remove(id);
            _formKeys.remove(id);
            _attachmentData.remove(id);
            _attachmentLabels.remove(id);
            _submittingIds.remove(id);
          }
        }
        for (final id in _radiologyForms.keys.toList()) {
          if (!liveIds.contains(id)) {
            _radiologyForms.remove(id)?.dispose();
          }
        }
      });
    } catch (e) {
      if (mounted && !silent) _showSnack(_apiErrorMessage(e), isError: true);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _loadCompletedExams({bool silent = false}) async {
    if (!_isRadiology) return;
    if (!silent) setState(() => _loadingCompleted = true);
    try {
      final list = await _api.completedRadiology();
      if (!mounted) return;
      setState(() => _completed = list.where(_matchesActiveDiscipline).toList());
    } catch (e) {
      if (mounted && !silent) _showSnack(_apiErrorMessage(e), isError: true);
    } finally {
      if (mounted && !silent) setState(() => _loadingCompleted = false);
    }
  }

  Future<void> _refreshRadiologyQueues() async {
    await Future.wait([
      _loadIncomingRequests(silent: true),
      _loadCompletedExams(silent: true),
    ]);
  }

  TextEditingController _controllerFor(String orderId) {
    return _analysisControllers.putIfAbsent(orderId, TextEditingController.new);
  }

  GlobalKey<FormState> _formKeyFor(String orderId) {
    return _formKeys.putIfAbsent(orderId, GlobalKey<FormState>.new);
  }

  RadiologyImagingFormState _radiologyFormFor(String orderId) {
    return _radiologyForms.putIfAbsent(orderId, RadiologyImagingFormState.new);
  }

  void _disposeRadiologyForm(String orderId) {
    _radiologyForms.remove(orderId)?.dispose();
    _formKeys.remove(orderId);
  }

  String _testRequestedLabel(BuildContext context, Map<String, dynamic> m) {
    final l10n = context.l10n;
    if (!_isRadiology) {
      final type = m['testType']?.toString().trim() ?? '';
      final name = m['testName']?.toString().trim() ?? '';
      if (type.isNotEmpty && name.isNotEmpty) return '$type: $name';
      if (type.isNotEmpty) return type;
      if (name.isNotEmpty) return name;
      return l10n.technicianLabTest;
    }
    final modality = m['modality']?.toString().trim() ?? '';
    final study = m['studyName']?.toString().trim() ?? '';
    if (modality.isNotEmpty && study.isNotEmpty) return '$modality: $study';
    if (modality.isNotEmpty) return modality;
    if (study.isNotEmpty) return study;
    return l10n.technicianImagingStudy;
  }

  String _formatTimestamp(dynamic raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} · $h:$min';
  }

  Future<void> _pickAttachment(String orderId, {required bool locked}) async {
    if (locked) return;
    final r = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final ext = (f.extension ?? 'pdf').toLowerCase();
    final mime = ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');
    setState(() {
      _attachmentData[orderId] = 'data:$mime;base64,${base64Encode(bytes)}';
      _attachmentLabels[orderId] = f.name;
    });
  }

  Future<void> _submitOrder(Map<String, dynamic> order) async {
    final orderId = order['_id']?.toString() ?? '';
    if (orderId.isEmpty || _submittingIds.contains(orderId)) return;
    if (order['isLocked'] == true || order['status'] == 'Completed') return;

    final formKey = _formKeyFor(orderId);
    if (!(formKey.currentState?.validate() ?? false)) return;

    if (_isRadiology) {
      final imagingForm = _radiologyFormFor(orderId);
      if (!imagingForm.canSubmit) {
        _showSnack(context.l10n.technicianAttachImagingBeforeSubmit, isError: true);
        return;
      }
    }

    final analysis = _isRadiology
        ? _radiologyFormFor(orderId).toResultAnalysisJson(order, _technicianDisplayName)
        : _controllerFor(orderId).text.trim();

    setState(() => _submittingIds.add(orderId));
    try {
      late final Map<String, dynamic> body;
      if (_isRadiology) {
        final imagingForm = _radiologyFormFor(orderId);
        body = {
          'resultAnalysis': analysis,
          'technicianNotes': imagingForm.notesController.text.trim(),
          if (imagingForm.attachmentDataUrl != null) 'attachmentUrl': imagingForm.attachmentDataUrl,
          if (imagingForm.attachmentName != null) 'attachmentName': imagingForm.attachmentName,
          if (imagingForm.attachmentMime != null) 'mimeType': imagingForm.attachmentMime,
        };
      } else {
        final label = _attachmentLabels[orderId] ?? '';
        body = {
          'resultAnalysis': analysis,
          'results': analysis,
          if (_attachmentData[orderId] != null) 'attachmentUrl': _attachmentData[orderId],
          if (label.isNotEmpty) 'attachmentName': label,
          if (label.isNotEmpty)
            'mimeType': label.toLowerCase().endsWith('.png') ? 'image/png' : 'application/pdf',
        };
      }
      await (_isRadiology ? _api.submitRadiology(orderId, body) : _api.submitLab(orderId, body));
      if (!mounted) return;
      _showSnack(_isRadiology
          ? context.l10n.technicianImagingReportSubmitted
          : context.l10n.technicianReportSubmitted);
      setState(() {
        _expandedIds.remove(orderId);
        if (_isRadiology) {
          _disposeRadiologyForm(orderId);
        } else {
          _analysisControllers[orderId]?.dispose();
          _analysisControllers.remove(orderId);
          _formKeys.remove(orderId);
          _attachmentData.remove(orderId);
          _attachmentLabels.remove(orderId);
        }
      });
      if (_isRadiology) {
        await _refreshRadiologyQueues();
      } else {
        await _loadIncomingRequests(silent: true);
      }
    } catch (e) {
      if (mounted) _showSnack(_apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _submittingIds.remove(orderId));
    }
  }

  Future<void> _logout() async {
    await TechnicianSession.instance.clear();
    TenantState.instance.clear();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => const LandingScreen()));
  }

  Widget _navIconWithBadge(IconData icon, {required bool selected, required int badgeCount}) {
    final iconWidget = Icon(icon, color: selected ? _kGold : Colors.white54, size: 24);
    if (badgeCount <= 0) return iconWidget;
    return Badge(
      isLabelVisible: true,
      backgroundColor: Colors.red.shade700,
      label: Text(
        badgeCount > 99 ? '99+' : '$badgeCount',
        style: GoogleFonts.urbanist(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
      child: iconWidget,
    );
  }

  Widget _sidebarNavTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required int index,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    final sel = _navIndex == index;
    return Material(
      color: sel ? _kGold.withValues(alpha: 0.1) : Colors.transparent,
      child: ListTile(
        tileColor: Colors.transparent,
        selectedTileColor: _kGold.withValues(alpha: 0.12),
        splashColor: _kGold.withValues(alpha: 0.2),
        hoverColor: _kGold.withValues(alpha: 0.08),
        selected: sel,
        leading: _navIconWithBadge(icon, selected: sel, badgeCount: badgeCount),
        title: Text(
          label,
          style: GoogleFonts.urbanist(
            color: sel ? _kGoldLight : Colors.white70,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.urbanist(
                  color: sel ? _kGold.withValues(alpha: 0.85) : Colors.white38,
                  fontSize: 11,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _sidebar(BuildContext context) {
    final l10n = context.l10n;
    final incomingIcon = _isRadiology ? Icons.radar_outlined : Icons.biotech_outlined;

    return Material(
      color: _kSidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.appTitle, style: GoogleFonts.playfairDisplay(color: _kGold, fontSize: 22, fontWeight: FontWeight.w700)),
                  Text(
                    _roleTitle(context),
                    style: GoogleFonts.urbanist(color: _kGoldLight, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  if ((_technicianDisplayName.isNotEmpty ? _technicianDisplayName : widget.userName ?? '').isNotEmpty)
                    Text(
                      _technicianDisplayName.isNotEmpty ? _technicianDisplayName : widget.userName!,
                      style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            if (!_isRadiology)
              Expanded(
                child: ListView(
                  children: [
                    _sidebarNavTile(
                      icon: Icons.dashboard_outlined,
                      label: l10n.technicianNavOverview,
                      index: 0,
                      onTap: () {
                        setState(() => _navIndex = 0);
                        if (MediaQuery.sizeOf(context).width < _kBreakpoint) Navigator.pop(context);
                      },
                    ),
                    _sidebarNavTile(
                      icon: incomingIcon,
                      label: l10n.technicianNavIncomingOrders,
                      subtitle: context.isArabicLocale ? null : l10n.technicianNavIncomingOrdersAr,
                      index: _incomingOrdersNavIndex,
                      badgeCount: _pendingBadgeCount,
                      onTap: () {
                        setState(() => _navIndex = _incomingOrdersNavIndex);
                        if (MediaQuery.sizeOf(context).width < _kBreakpoint) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              )
            else
              const Spacer(),
            Material(
              color: Colors.transparent,
              child: ListTile(
                tileColor: Colors.transparent,
                splashColor: _kGold.withValues(alpha: 0.12),
                leading: const Icon(Icons.time_to_leave_outlined, color: _kGold),
                title: Text(
                  leaveRequestsNavLabel(context),
                  style: GoogleFonts.urbanist(color: Colors.white70),
                ),
                onTap: () {
                  if (MediaQuery.sizeOf(context).width < _kBreakpoint) Navigator.pop(context);
                  openLeaveRequestScreen(context, userId: widget.userId);
                },
              ),
            ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                tileColor: Colors.transparent,
                splashColor: Colors.redAccent.withValues(alpha: 0.15),
                hoverColor: Colors.redAccent.withValues(alpha: 0.08),
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text(l10n.logOut, style: GoogleFonts.urbanist(color: Colors.white70)),
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewPage(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          color: AuthSignupColors.glassCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _kGold.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.technicianWelcome, style: AuthSignupTheme.sectionTitleStyle(fontSize: 22)),
                const SizedBox(height: 8),
                Text(
                  _isRadiology ? l10n.technicianRadiologyOverviewHint : l10n.technicianLabOverviewHint,
                  style: GoogleFonts.urbanist(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Badge(
                      isLabelVisible: _pendingBadgeCount > 0,
                      backgroundColor: Colors.red.shade700,
                      label: Text('$_pendingBadgeCount'),
                      child: Icon(Icons.assignment_outlined, color: _kGold.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.technicianPendingOrdersCount(_pendingBadgeCount),
                      style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AuthSignupTheme.primaryButton(
                  label: l10n.technicianOpenIncomingOrders,
                  onPressed: () => setState(() => _navIndex = _incomingOrdersNavIndex),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _greetingPanel(BuildContext context) {
    final l10n = context.l10n;
    final displayName = _technicianDisplayName.isNotEmpty
        ? _technicianDisplayName
        : (widget.userName?.trim().isNotEmpty == true ? widget.userName!.trim() : '');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AuthSignupColors.glassCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGold.withValues(alpha: 0.4)),
            ),
            child: Icon(
              _isRadiology ? Icons.radar_outlined : Icons.biotech_outlined,
              color: _kGoldLight,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isNotEmpty ? l10n.technicianWelcomeName(displayName) : l10n.technicianWelcome,
                  style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  _roleTitle(context),
                  style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _isRadiology ? l10n.technicianRadiologyGreetingHint : l10n.technicianLabGreetingHint,
                  style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _radiologyTabBar(BuildContext context) {
    final l10n = context.l10n;
    final tabs = _orderTabs;
    if (tabs == null) return const SizedBox.shrink();
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      child: TabBar(
        controller: tabs,
        indicatorColor: _kGold,
        indicatorWeight: 3,
        labelColor: _kGoldLight,
        unselectedLabelColor: Colors.white54,
        labelStyle: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.urbanist(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.technicianTabIncomingRequests),
                if (_pendingBadgeCount > 0) ...[
                  const SizedBox(width: 8),
                  Badge(
                    backgroundColor: Colors.red.shade700,
                    label: Text(
                      _pendingBadgeCount > 99 ? '99+' : '$_pendingBadgeCount',
                      style: GoogleFonts.urbanist(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(text: l10n.technicianTabCompletedExams),
        ],
      ),
    );
  }

  Widget _emptyImagingState(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _greetingPanel(context),
        const SizedBox(height: 48),
        Icon(icon, size: 48, color: _kGold.withValues(alpha: 0.45)),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(color: Colors.white38, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _incomingRequestsList(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AuthSignupColors.gold));
    }
    if (_pending.isEmpty) {
      return _emptyImagingState(
        context,
        title: l10n.technicianNoPendingImagingRequests,
        subtitle: l10n.technicianNoPendingImagingSubtitle,
        icon: Icons.radar_outlined,
      );
    }
    return RefreshIndicator(
      color: _kGold,
      backgroundColor: AuthSignupColors.glassCard,
      onRefresh: () => _loadIncomingRequests(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: _pending.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return _greetingPanel(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _orderCard(context, _pending[i - 1]),
          );
        },
      ),
    );
  }

  Widget _completedExamsList(BuildContext context) {
    final l10n = context.l10n;
    if (_loadingCompleted) {
      return const Center(child: CircularProgressIndicator(color: AuthSignupColors.gold));
    }
    if (_completed.isEmpty) {
      return _emptyImagingState(
        context,
        title: l10n.technicianNoCompletedImagingExams,
        subtitle: l10n.technicianNoCompletedImagingSubtitle,
        icon: Icons.check_circle_outline,
      );
    }
    return RefreshIndicator(
      color: _kGold,
      backgroundColor: AuthSignupColors.glassCard,
      onRefresh: () => _loadCompletedExams(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: _completed.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return _greetingPanel(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _completedOrderCard(context, _completed[i - 1]),
          );
        },
      ),
    );
  }

  Widget _radiologyOrdersPage(BuildContext context) {
    final tabs = _orderTabs;
    if (tabs == null) return _incomingRequestsList(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _radiologyTabBar(context),
        Expanded(
          child: TabBarView(
            controller: tabs,
            children: [
              _incomingRequestsList(context),
              _completedExamsList(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ordersPage(BuildContext context) {
    if (_isRadiology) return _radiologyOrdersPage(context);

    final l10n = context.l10n;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AuthSignupColors.gold));
    }
    if (_pending.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _greetingPanel(context),
          const SizedBox(height: 48),
          Icon(Icons.assignment_outlined, size: 48, color: _kGold.withValues(alpha: 0.45)),
          const SizedBox(height: 12),
          Text(
            l10n.technicianNoIncomingOrders,
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.technicianNoIncomingOrdersSubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: _kGold,
      backgroundColor: AuthSignupColors.glassCard,
      onRefresh: () => _loadIncomingRequests(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: _pending.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return _greetingPanel(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _orderCard(context, _pending[i - 1]),
          );
        },
      ),
    );
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
        style: GoogleFonts.urbanist(color: _kGoldLight, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _orderCard(BuildContext context, Map<String, dynamic> order) {
    final l10n = context.l10n;
    final orderId = order['_id']?.toString() ?? '';
    final patient = order['patient'] is Map
        ? Map<String, dynamic>.from(order['patient'] as Map)
        : <String, dynamic>{};
    final locked = order['isLocked'] == true || order['status'] == 'Completed';
    final expanded = _expandedIds.contains(orderId);
    final submitting = _submittingIds.contains(orderId);
    final controller = _controllerFor(orderId);
    final attachmentLabel = _attachmentLabels[orderId] ?? '';
    final statusLabel = _displayStatus(context, order['status']?.toString());
    final patientId = order['patientUserId']?.toString() ??
        patient['patientId']?.toString() ??
        patient['id']?.toString() ??
        '—';

    return Card(
      color: AuthSignupColors.glassCard,
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
                  child: Icon(
                    _isRadiology ? Icons.radar_outlined : Icons.biotech_outlined,
                    color: _kGoldLight,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['fullName']?.toString() ?? l10n.patient,
                        style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      _metricRow(l10n.technicianPatientId, patientId),
                      const SizedBox(height: 4),
                      if (_isRadiology) ...[
                        _metricRow(l10n.technicianModalityExamType, _imagingModalityLabel(order)),
                        const SizedBox(height: 4),
                        _metricRow(l10n.technicianBodyPart, _imagingBodyPartLabel(order)),
                        const SizedBox(height: 4),
                        _metricRow(l10n.technicianOrderingPhysician, order['doctorName']?.toString().trim().isNotEmpty == true
                            ? order['doctorName']!.toString().trim()
                            : '—'),
                        const SizedBox(height: 4),
                        _metricRow(l10n.technicianReasonForExam, order['notes']?.toString().trim().isNotEmpty == true
                            ? order['notes']!.toString().trim()
                            : '—'),
                      ] else ...[
                        _metricRow(l10n.technicianTestRequested, _testRequestedLabel(context, order)),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        l10n.technicianOrderedAt(_formatTimestamp(order['createdAt'] ?? order['updatedAt'])),
                        style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _statusBadge(statusLabel),
              ],
            ),
            const SizedBox(height: 14),
            if (locked)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGold.withValues(alpha: 0.45)),
                ),
                child: Text(
                  l10n.technicianReportFinalized,
                  style: GoogleFonts.urbanist(color: _kGoldLight, fontSize: 13),
                ),
              )
            else if (!expanded)
              OutlinedButton.icon(
                style: AuthSignupTheme.outlineButtonStyle(),
                onPressed: () => setState(() => _expandedIds.add(orderId)),
                icon: const Icon(Icons.edit_note_outlined, color: AuthSignupColors.gold, size: 20),
                label: Text(
                  _isRadiology ? l10n.technicianEnterImagingResults : l10n.technicianEnterResults,
                  style: GoogleFonts.urbanist(color: _kGoldLight, fontWeight: FontWeight.w700),
                ),
              )
            else ...[
              Form(
                key: _formKeyFor(orderId),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isRadiology)
                      RadiologyImagingResultForm(
                        order: order,
                        technicianName: _technicianDisplayName,
                        formState: _radiologyFormFor(orderId),
                        onChanged: () => setState(() {}),
                      )
                    else ...[
                      Text(
                        l10n.technicianResultAnalysisNotes,
                        style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: controller,
                        maxLines: 5,
                        style: AuthSignupTheme.fieldTextStyle(),
                        decoration: AuthSignupTheme.inputDecoration(
                          l10n.technicianEnterDiagnosticFindings,
                          prefixIcon: Icons.notes_outlined,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? l10n.technicianAnalysisNotesRequired : null,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: AuthSignupTheme.outlineButtonStyle(),
                        onPressed: () => _pickAttachment(orderId, locked: locked),
                        icon: Icon(
                          attachmentLabel.isNotEmpty ? Icons.check_circle_outline : Icons.upload_file,
                          color: AuthSignupColors.gold,
                        ),
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.technicianAttachDocument),
                              if (attachmentLabel.isNotEmpty)
                                Text(
                                  attachmentLabel,
                                  style: GoogleFonts.urbanist(fontSize: 11, color: AuthSignupColors.goldLight),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AuthSignupTheme.primaryButton(
                            label: _isRadiology ? l10n.technicianSubmitImagingReport : l10n.technicianSubmitReport,
                            loading: submitting,
                            onPressed: () => _submitOrder(order),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          style: AuthSignupTheme.outlineButtonStyle(),
                          onPressed: submitting
                              ? null
                              : () => setState(() {
                                    _expandedIds.remove(orderId);
                                    if (_isRadiology) {
                                      _disposeRadiologyForm(orderId);
                                    }
                                  }),
                          child: Text(l10n.cancel, style: GoogleFonts.urbanist(color: Colors.white54)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _imagingModalityLabel(Map<String, dynamic> order) {
    final modality = order['modality']?.toString().trim() ?? '';
    final examType = order['examType']?.toString().trim() ?? '';
    if (modality.isNotEmpty && examType.isNotEmpty) return '$modality · $examType';
    if (modality.isNotEmpty) return modality;
    if (examType.isNotEmpty) return examType;
    return '—';
  }

  String _imagingBodyPartLabel(Map<String, dynamic> order) {
    final bodyPart = order['bodyPart']?.toString().trim() ?? '';
    final study = order['studyName']?.toString().trim() ?? '';
    if (bodyPart.isNotEmpty) return bodyPart;
    if (study.isNotEmpty) return study;
    return '—';
  }

  Widget _completedOrderCard(BuildContext context, Map<String, dynamic> order) {
    final l10n = context.l10n;
    final patient = order['patient'] is Map
        ? Map<String, dynamic>.from(order['patient'] as Map)
        : <String, dynamic>{};
    final patientId = order['patientUserId']?.toString() ??
        patient['patientId']?.toString() ??
        patient['id']?.toString() ??
        '—';

    return Card(
      color: AuthSignupColors.glassCard,
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
                  child: const Icon(Icons.radar_outlined, color: _kGoldLight, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['fullName']?.toString() ?? l10n.patient,
                        style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      _metricRow(l10n.technicianPatientId, patientId),
                      const SizedBox(height: 4),
                      _metricRow(l10n.technicianModalityExamType, _imagingModalityLabel(order)),
                      const SizedBox(height: 4),
                      _metricRow(l10n.technicianBodyPart, _imagingBodyPartLabel(order)),
                      const SizedBox(height: 4),
                      _metricRow(l10n.technicianOrderingPhysician, order['doctorName']?.toString().trim().isNotEmpty == true
                          ? order['doctorName']!.toString().trim()
                          : '—'),
                      const SizedBox(height: 4),
                      Text(
                        l10n.technicianCompletedAt(_formatTimestamp(order['completedAt'] ?? order['updatedAt'])),
                        style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _statusBadge(l10n.technicianStatusCompleted),
              ],
            ),
            if ((order['resultAnalysis']?.toString().trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGold.withValues(alpha: 0.45)),
                ),
                child: Text(
                  order['resultAnalysis']!.toString().trim(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: GoogleFonts.urbanist(color: _kGold, fontSize: 11)),
        ),
        Expanded(
          child: Text(value, style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 12)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= _kBreakpoint;
    final pageTitle = _isRadiology
        ? l10n.technicianImagingWorkflow
        : (_navIndex == 0 ? l10n.technicianNavOverview : l10n.technicianNavIncomingOrders);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AuthSignupColors.scaffoldBlack,
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: _kSidebar,
              child: _sidebar(context),
            ),
      body: Container(
        decoration: AuthSignupTheme.gradientBackgroundDecoration(),
        child: Row(
          children: [
            if (wide) SizedBox(width: 240, child: _sidebar(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          if (!wide)
                            IconButton(
                              icon: const Icon(Icons.menu, color: _kGoldLight),
                              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                            ),
                          Text(pageTitle, style: GoogleFonts.urbanist(color: _kGold, fontSize: 18, fontWeight: FontWeight.w700)),
                          if (!_isRadiology && _navIndex == _incomingOrdersNavIndex && _pendingBadgeCount > 0) ...[
                            const SizedBox(width: 10),
                            Badge(
                              backgroundColor: Colors.red.shade700,
                              label: Text(
                                '$_pendingBadgeCount',
                                style: GoogleFonts.urbanist(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                          const Spacer(),
                          const RafeeqLanguageToggle(iconColor: _kGoldLight),
                          if (_isRadiology || _navIndex == _incomingOrdersNavIndex)
                            IconButton(
                              tooltip: l10n.refresh,
                              icon: const Icon(Icons.refresh, color: _kGoldLight),
                              onPressed: (_loading || _loadingCompleted)
                                  ? null
                                  : () {
                                      if (_isRadiology) {
                                        _refreshRadiologyQueues();
                                      } else {
                                        _loadIncomingRequests();
                                      }
                                    },
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isRadiology
                        ? _radiologyOrdersPage(context)
                        : (_navIndex == 0 ? _overviewPage(context) : _ordersPage(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
