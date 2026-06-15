import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../utils/allergy_display.dart';
import '../data/patient_backorder_item.dart';
import '../data/patient_portal_api.dart';
import '../data/patient_navigation_bus.dart';
import 'patient_active_backorder_panel.dart';
import 'patient_pharmacy_purchase_sheet.dart';
import 'patient_theme.dart';
export 'patient_book_screen.dart' show PatientBookingTab;

/// Pharmacy + health tabs (Book tab lives in [patient_book_screen.dart]).
class PatientPharmacyTab extends StatefulWidget {
  final String patientUserId;
  final bool isTabActive;

  const PatientPharmacyTab({
    super.key,
    required this.patientUserId,
    this.isTabActive = true,
  });

  @override
  State<PatientPharmacyTab> createState() => _PatientPharmacyTabState();
}

class _PatientPharmacyTabState extends State<PatientPharmacyTab> {
  final _q = TextEditingController();
  List<dynamic> _results = [];
  List<dynamic> _nearbyPharmacies = [];
  bool _busy = false;
  List<PatientBackorderItem> _activeBackordersList = [];
  final Set<String> _dismissedBackorderIds = {};
  bool _loadingBackorders = false;
  bool _handlingDeepLink = false;
  String? _activePrescriptionId;
  List<PrescriptionCartItem> _prescriptionCart = [];

  @override
  void dispose() {
    PatientNavigationBus.pending.removeListener(_onNavigationIntent);
    _q.dispose();
    super.dispose();
  }

  void _onNavigationIntent() {
    _consumePendingIntent();
  }

  @override
  void initState() {
    super.initState();
    PatientNavigationBus.pending.addListener(_onNavigationIntent);
    _search();
    _loadNearbyPharmacies();
    fetchActivePatientBackorders();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingIntent());
  }

  @override
  void didUpdateWidget(PatientPharmacyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      fetchActivePatientBackorders();
    }
  }

  List<PatientBackorderItem> get _visibleBackorders => _activeBackordersList
      .where((item) => !_dismissedBackorderIds.contains(item.id))
      .toList();

  Future<void> fetchActivePatientBackorders() async {
    if (!mounted) return;
    setState(() => _loadingBackorders = true);
    try {
      final list = await PatientPortalApi.fetchActivePatientBackorders(widget.patientUserId);
      if (!mounted) return;
      setState(() {
        _activeBackordersList = list;
        _loadingBackorders = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBackorders = false);
    }
  }

  void _dismissBackorder(String id) {
    setState(() => _dismissedBackorderIds.add(id));
  }

  void _dismissAllBackorders() {
    setState(() {
      for (final item in _visibleBackorders) {
        _dismissedBackorderIds.add(item.id);
      }
    });
  }

  Future<void> _consumePendingIntent() async {
    final intent = PatientNavigationBus.pending.value;
    if (intent == null || !intent.isPharmacyDeepLink || _handlingDeepLink) return;

    _handlingDeepLink = true;
    PatientNavigationBus.clear();

    if (intent.isPrescriptionPharmacyFilter) {
      await _applyPrescriptionPharmacyFilter(intent);
      if (intent.isFromPrescription) {
        await _loadPrescriptionCart(intent);
      }
    } else {
      await _ensureDrugVisible(intent);
    }

    if (!mounted) {
      _handlingDeepLink = false;
      return;
    }

    if (intent.openPurchaseSheet) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) await _openPurchaseFlowFromIntent(intent);
    }

    _handlingDeepLink = false;
  }

  Future<void> _loadPrescriptionCart(PatientNavigationIntent intent) async {
    final prescriptionId = intent.prescriptionId?.trim() ?? '';
    if (prescriptionId.isEmpty || intent.cartItems.isEmpty) return;

    setState(() {
      _activePrescriptionId = prescriptionId;
      _prescriptionCart = List<PrescriptionCartItem>.from(intent.cartItems);
    });

    for (final item in intent.cartItems) {
      await _ensureDrugVisible(
        PatientNavigationIntent(
          type: 'PRESCRIPTION_PHARMACY',
          drugId: item.drugId,
          drugName: item.medicationName,
          prescriptionId: prescriptionId,
          isFromPrescription: true,
        ),
      );
    }

    if (!mounted) return;
    final count = _prescriptionCart.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Prescription cart loaded — $count medication${count == 1 ? '' : 's'} authorized for checkout.',
        ),
        backgroundColor: kPatientGoldDeep,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _isAuthorizedPrescriptionDrug(String drugId) {
    if (_activePrescriptionId == null || _activePrescriptionId!.trim().isEmpty) return false;
    return _prescriptionCart.any((item) => item.drugId == drugId);
  }

  PrescriptionCartItem? _cartItemForDrug(String drugId) {
    for (final item in _prescriptionCart) {
      if (item.drugId == drugId) return item;
    }
    return null;
  }

  Future<void> _checkoutPrescriptionCart() async {
    final prescriptionId = _activePrescriptionId?.trim() ?? '';
    if (prescriptionId.isEmpty || _prescriptionCart.isEmpty || _busy) return;

    setState(() => _busy = true);
    final remaining = List<PrescriptionCartItem>.from(_prescriptionCart);
    var completed = 0;

    for (final item in remaining) {
      if (!mounted) break;
      final purchased = await showPatientPharmacyPurchaseSheet(
        context,
        patientUserId: widget.patientUserId,
        drugId: item.drugId,
        drugName: item.medicationName,
        requiresPrescription: true,
        prescriptionId: prescriptionId,
        medicationId: item.drugId,
        maxQuantity: item.maxQuantity,
      );
      if (purchased == true) {
        completed++;
        if (mounted) {
          setState(() {
            _prescriptionCart.removeWhere((c) => c.drugId == item.drugId);
          });
        }
      } else {
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (_prescriptionCart.isEmpty) _activePrescriptionId = null;
    });
    await fetchActivePatientBackorders();

    if (completed > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            completed == remaining.length
                ? 'Prescription order submitted for all medications.'
                : 'Submitted $completed of ${remaining.length} prescribed medications.',
          ),
          backgroundColor: kPatientGoldDeep,
        ),
      );
    }
  }

  Widget _prescriptionCartPanel() {
    if (_prescriptionCart.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPatientFieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPatientGold.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, color: kPatientGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prescription cart (${_prescriptionCart.length})',
                  style: patientTitleStyle(15),
                ),
              ),
              IconButton(
                tooltip: 'Clear cart',
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _prescriptionCart = [];
                          _activePrescriptionId = null;
                        }),
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._prescriptionCart.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.medication_outlined, color: kPatientGoldLight, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.medicationName,
                      style: patientBodyStyle(color: Colors.white70, size: 13),
                    ),
                  ),
                  if (item.maxQuantity != null)
                    Text(
                      'Qty ${item.maxQuantity}',
                      style: patientBodyStyle(color: Colors.white54, size: 12),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _checkoutPrescriptionCart,
              style: FilledButton.styleFrom(
                backgroundColor: kPatientGold,
                foregroundColor: kPatientWorkspaceBlack,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: kPatientWorkspaceBlack),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(
                _busy ? 'Processing…' : 'Checkout prescription order',
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyPrescriptionPharmacyFilter(PatientNavigationIntent intent) async {
    final names = intent.filterMedicationNames;
    if (names.isNotEmpty) {
      _q.text = names.first;
    } else if (intent.drugName != null && intent.drugName!.trim().isNotEmpty) {
      _q.text = intent.drugName!.trim();
    }

    await _search();

    if (!mounted) return;

    final filterIds = intent.filterDrugIds.toSet();
    if (filterIds.isEmpty && names.isEmpty) return;

    setState(() {
      _results = _results.where((entry) {
        if (entry is! Map) return false;
        final m = Map<String, dynamic>.from(entry);
        final id = m['_id']?.toString() ?? m['id']?.toString() ?? '';
        if (filterIds.isNotEmpty && filterIds.contains(id)) return true;
        if (names.isEmpty) return false;
        final name = m['name']?.toString().toLowerCase() ?? '';
        return names.any((rxName) => name.contains(rxName.toLowerCase()));
      }).toList();
    });
  }

  Future<void> _ensureDrugVisible(PatientNavigationIntent intent) async {
    final drugId = intent.drugId;
    final alreadyListed = _results.any((e) {
      if (e is! Map) return false;
      final id = e['_id']?.toString() ?? e['id']?.toString() ?? '';
      return id == drugId;
    });
    if (alreadyListed) return;

    final query = intent.drugName?.trim() ?? '';
    if (query.isNotEmpty) {
      _q.text = query;
      await _search();
      return;
    }

    try {
      final catalog = await PatientPortalApi.pharmacySearch(widget.patientUserId, '');
      Map<String, dynamic>? match;
      for (final e in catalog) {
        if (e is! Map) continue;
        final id = e['_id']?.toString() ?? e['id']?.toString() ?? '';
        if (id == drugId) {
          match = Map<String, dynamic>.from(e);
          break;
        }
      }
      if (match != null && mounted) {
        setState(() {
          if (!_results.any((r) => (r as Map)['_id']?.toString() == drugId)) {
            _results = [match!, ..._results];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _openPurchaseFlowFromIntent(PatientNavigationIntent intent) async {
    Map<String, dynamic>? drugRow;
    for (final e in _results) {
      if (e is! Map) continue;
      final id = e['_id']?.toString() ?? e['id']?.toString() ?? '';
      if (id == intent.drugId) {
        drugRow = Map<String, dynamic>.from(e);
        break;
      }
    }

    final name = drugRow?['name']?.toString() ?? intent.drugName ?? 'Medication';
    final requiresRx = drugRow?['requiresPrescription'] == true;

    if (requiresRx && (intent.prescriptionId == null || intent.prescriptionId!.trim().isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Prescription required — open My Prescriptions and purchase from your active Rx.',
          ),
        ),
      );
      return;
    }

    await showPatientPharmacyPurchaseSheet(
      context,
      patientUserId: widget.patientUserId,
      drugId: intent.drugId,
      drugName: name,
      requiresPrescription: requiresRx,
      prescriptionId: intent.prescriptionId,
      medicationId: intent.drugId,
    );
  }

  Future<void> _search() async {
    setState(() => _busy = true);
    try {
      final list = await PatientPortalApi.pharmacySearch(widget.patientUserId, _q.text.trim());
      if (mounted) setState(() => _results = list);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.patientSearchFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadNearbyPharmacies() async {
    setState(() => _busy = true);
    try {
      final list = await PatientPortalApi.nearbyPharmacies(widget.patientUserId);
      if (mounted) setState(() => _nearbyPharmacies = list);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const Color _subtitleGray = Color(0xFFB0B0B0);

  Future<void> _openPurchaseFlow(BuildContext context, Map<String, dynamic> m) async {
    final name = m['name']?.toString() ?? 'Item';
    final drugId = m['_id']?.toString() ?? m['id']?.toString() ?? '';
    final requiresRx = m['requiresPrescription'] == true;
    final authorized = _isAuthorizedPrescriptionDrug(drugId);
    final cartItem = _cartItemForDrug(drugId);

    if (requiresRx && !authorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientPrescriptionRequiredPharmacy)),
      );
      return;
    }

    if (drugId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.patientCatalogIdMissing)),
      );
      return;
    }

    await showPatientPharmacyPurchaseSheet(
      context,
      patientUserId: widget.patientUserId,
      drugId: drugId,
      drugName: name,
      requiresPrescription: requiresRx,
      prescriptionId: authorized ? _activePrescriptionId : null,
      medicationId: drugId,
      maxQuantity: cartItem?.maxQuantity,
    );
    if (mounted) await fetchActivePatientBackorders();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _q,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: kPatientGold,
                  decoration: patientInputDec(l10n.patientSearchClinicStock).copyWith(
                    isDense: true,
                    hintStyle: patientBodyStyle(color: Colors.white38, size: 14),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _search,
                style: FilledButton.styleFrom(
                  backgroundColor: kPatientGoldDeep,
                  foregroundColor: Colors.black,
                ),
                child: Text(l10n.patientGo, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                if (_loadingBackorders && _visibleBackorders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kPatientGold),
                      ),
                    ),
                  ),
                PatientActiveBackordersSection(
                  patientUserId: widget.patientUserId,
                  items: _visibleBackorders,
                  onDismissAll: _visibleBackorders.isEmpty ? null : _dismissAllBackorders,
                  onDismissItem: _dismissBackorder,
                ),
                _prescriptionCartPanel(),
                Text(
                  l10n.patientClinicPharmacy,
                  style: patientTitleStyle(16),
                ),
                ..._results.map((e) {
                  final m = e as Map<String, dynamic>;
                  final drugId = m['_id']?.toString() ?? m['id']?.toString() ?? '';
                  final inStock = m['inStock'] != false;
                  final stockLabel = inStock ? l10n.patientInStock : l10n.patientOutOfStock;
                  final requiresRx = m['requiresPrescription'] == true;
                  final rxAuthorized = requiresRx && _isAuthorizedPrescriptionDrug(drugId);
                  return ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            m['name']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (requiresRx)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: rxAuthorized
                                  ? kPatientGold.withValues(alpha: 0.15)
                                  : Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              rxAuthorized ? l10n.patientRxAuthorized : l10n.patientRx,
                              style: GoogleFonts.urbanist(
                                color: rxAuthorized ? kPatientGoldLight : Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${m['category'] ?? m['strength'] ?? ''} · $stockLabel',
                      style: const TextStyle(color: _subtitleGray, fontSize: 13),
                    ),
                    trailing: requiresRx && !rxAuthorized
                        ? TextButton(
                            onPressed: null,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade500,
                              disabledForegroundColor: Colors.grey.shade500,
                            ),
                            child: Text(
                              l10n.patientPrescriptionRequired,
                              style: GoogleFonts.urbanist(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          )
                        : TextButton(
                            onPressed: inStock ? () => _openPurchaseFlow(context, m) : null,
                            style: TextButton.styleFrom(foregroundColor: kPatientGoldLight),
                            child: Text(
                              rxAuthorized ? l10n.patientBuyRx : l10n.patientBuy,
                              style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
                            ),
                          ),
                  );
                }),
                Divider(height: 32, color: Colors.white24),
                Text(
                  l10n.patientNearbyPharmacies,
                  style: patientTitleStyle(16),
                ),
                ..._nearbyPharmacies.map((e) {
                  final m = e as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.local_pharmacy, color: kPatientGold),
                    title: Text(
                      m['name']?.toString() ?? '',
                      style: const TextStyle(
                        color: kPatientGold,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      '${m['distanceKm'] ?? '?'} km · ${m['address'] ?? ''}',
                      style: const TextStyle(color: _subtitleGray, fontSize: 13),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PatientHealthDigitalTab extends StatefulWidget {
  final String patientUserId;

  const PatientHealthDigitalTab({super.key, required this.patientUserId});

  @override
  State<PatientHealthDigitalTab> createState() => _PatientHealthDigitalTabState();
}

class _PatientHealthDigitalTabState extends State<PatientHealthDigitalTab> {
  Map<String, dynamic>? _profile;
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
      final h = await PatientPortalApi.getHealthProfile(widget.patientUserId);
      if (!mounted) return;
      setState(() {
        _profile = h;
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

  String _display(dynamic value, {String empty = '—'}) {
    if (value == null) return empty;
    final text = value.toString().trim();
    return text.isEmpty ? empty : text;
  }

  String _listDisplay(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).join(' · ');
    }
    return '—';
  }

  Map<String, dynamic> get _nurseVitals {
    final raw = _profile?['latestNurseVitals'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  String get _allergiesDisplay {
    final explicit = _profile?['allergiesDisplay']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return formatAllergiesForDisplay(_profile?['allergies']);
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(title, style: patientTitleStyle(16)),
    );
  }

  Widget _sectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Divider(color: kPatientGold.withValues(alpha: 0.35), thickness: 1),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPatientFieldFill.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPatientGold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _readonlyField({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121614),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPatientGoldLight.withValues(alpha: 0.85), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: patientBodyStyle(color: kPatientGoldLight, size: 12)),
                const SizedBox(height: 4),
                Text(value, style: patientBodyStyle(color: Colors.white, size: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _allergiesHistoryBox() {
    final hasAllergies = _allergiesDisplay != '—' && _allergiesDisplay.toLowerCase() != 'none recorded';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasAllergies ? Colors.redAccent.withValues(alpha: 0.1) : const Color(0xFF121614),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAllergies ? Colors.redAccent.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: hasAllergies ? Colors.redAccent.shade200 : kPatientGoldLight.withValues(alpha: 0.7),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سجل الحساسية / Allergies',
                  style: patientBodyStyle(color: kPatientGoldLight, size: 13).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  _allergiesDisplay,
                  style: patientBodyStyle(color: Colors.white, size: 14).copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalsRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPatientGold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: patientBodyStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    final vitals = _nurseVitals;
    final bpSys = vitals['bloodPressureSystolic'];
    final bpDia = vitals['bloodPressureDiastolic'];
    final bpFallback = vitals['bloodPressureDisplay']?.toString();
    final bpDisplay = bpSys != null && bpDia != null
        ? '$bpSys / $bpDia'
        : _display(bpFallback);

    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth > 800 ? 720.0 : c.maxWidth;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: RefreshIndicator(
              color: kPatientGold,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l10n.patientDigitalHealthProfile, style: patientTitleStyle(20)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.patientOfficialMedicalReadOnly,
                    style: patientBodyStyle(color: Colors.white54, size: 13),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('📋 التاريخ الطبي العام'),
                  _sectionCard(
                    children: [
                      _readonlyField(
                        icon: Icons.bloodtype_outlined,
                        label: 'Blood type / فصيلة الدم',
                        value: _display(_profile?['bloodType']),
                      ),
                      _readonlyField(
                        icon: Icons.healing_outlined,
                        label: 'Chronic diseases / الأمراض المزمنة',
                        value: _listDisplay(_profile?['chronicDiseases']),
                      ),
                      _readonlyField(
                        icon: Icons.medical_information_outlined,
                        label: 'Past surgeries / العمليات السابقة',
                        value: _listDisplay(_profile?['pastSurgeries']),
                      ),
                      const SizedBox(height: 4),
                      _allergiesHistoryBox(),
                    ],
                  ),
                  _sectionDivider(),
                  _sectionTitle('🩺 المؤشرات الحيوية الحالية (تسجيل التمريض)'),
                  _sectionCard(
                    children: [
                      _vitalsRow([
                        _readonlyField(
                          icon: Icons.height_outlined,
                          label: 'Height (cm)',
                          value: _display(vitals['heightCm']),
                        ),
                        _readonlyField(
                          icon: Icons.monitor_weight_outlined,
                          label: 'Weight (kg)',
                          value: _display(vitals['weightKg']),
                        ),
                      ]),
                      _vitalsRow([
                        _readonlyField(
                          icon: Icons.favorite_outline,
                          label: 'BP systolic',
                          value: _display(bpSys),
                        ),
                        _readonlyField(
                          icon: Icons.favorite_border,
                          label: 'BP diastolic',
                          value: _display(bpDia),
                        ),
                      ]),
                      if (bpDisplay != '—')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Blood pressure reading: $bpDisplay',
                            style: patientBodyStyle(color: Colors.white54, size: 12),
                          ),
                        ),
                      _vitalsRow([
                        _readonlyField(
                          icon: Icons.monitor_heart_outlined,
                          label: 'Pulse rate (BPM)',
                          value: _display(vitals['pulseBpm']),
                        ),
                        _readonlyField(
                          icon: Icons.thermostat_outlined,
                          label: 'Temperature (°C)',
                          value: _display(vitals['temperatureC']),
                        ),
                      ]),
                      if (vitals['recordedAt'] != null)
                        Text(
                          'Last nursing entry: ${_display(vitals['recordedAt'])}',
                          style: patientBodyStyle(color: Colors.white38, size: 12),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
