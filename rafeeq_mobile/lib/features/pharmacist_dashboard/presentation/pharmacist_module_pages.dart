import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../auth/services/nominatim_service.dart';
import '../../auth/widgets/pharmacy_location_picker.dart';
import '../../auth/widgets/pharmacy_operating_hours_picker.dart';
import '../data/pharmacy_inventory_api.dart';
import 'pharmacist_layout.dart';
import 'pharmacist_profile_photo_picker.dart';
import 'pharmacist_theme.dart';

export 'pharmacist_inventory_view.dart';

// ─── Shared widgets ───────────────────────────────────────────────────────────

Widget _pageHeader(String title, String subtitle) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: PharmacistTheme.titleStyle()),
        const SizedBox(height: 4),
        Text(subtitle, style: PharmacistTheme.bodyStyle()),
      ],
    ),
  );
}

Widget statusBadge(String status) {
  Color color;
  switch (status) {
    case 'Low Stock':
      color = PharmacistTheme.orange;
      break;
    case 'Out of Stock':
      color = PharmacistTheme.red;
      break;
    default:
      color = PharmacistTheme.green;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(status, style: GoogleFonts.urbanist(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

// ─── 1. Dashboard Overview ────────────────────────────────────────────────────

class PharmacistOverviewPage extends StatefulWidget {
  const PharmacistOverviewPage({super.key, required this.workspace});
  final PharmacyWorkspace workspace;

  @override
  State<PharmacistOverviewPage> createState() => _PharmacistOverviewPageState();
}

class _PharmacistOverviewPageState extends State<PharmacistOverviewPage> {
  List<PharmacyAlert> _alerts = [];
  bool _loadingAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    widget.workspace.refreshPendingMedicationRequests();
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await widget.workspace.api.getNotifications(widget.workspace.pharmacyId);
      if (mounted) setState(() { _alerts = alerts.take(8).toList(); _loadingAlerts = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingAlerts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = widget.workspace.stats;
    return RefreshIndicator(
      color: PharmacistTheme.gold,
      onRefresh: () async {
        await widget.workspace.onRefresh();
        await widget.workspace.refreshPendingMedicationRequests();
        await _loadAlerts();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _pageHeader(l10n.pharmacistNavDashboardOverview, l10n.pharmacistDashboardSubtitle)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.crossAxisExtent;
                final cols = w >= 1200 ? 4 : (w >= 700 ? 2 : 1);
                final cards = [
                  _StatCard(l10n.pharmacistTotalDrugs, '${s.totalDrugs}', Icons.medication, PharmacistTheme.gold),
                  _StatCard(l10n.pharmacistAvailable, '${s.availableDrugs}', Icons.check_circle_outline, PharmacistTheme.green),
                  _StatCard(l10n.pharmacistLowStock, '${s.lowStockItems}', Icons.warning_amber, PharmacistTheme.orange),
                  _StatCard(l10n.pharmacistOutOfStock, '${s.outOfStockItems}', Icons.remove_shopping_cart, PharmacistTheme.red),
                ];
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: cols == 1 ? 2.5 : 1.4,
                  ),
                  delegate: SliverChildListDelegate(cards),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: ValueListenableBuilder<int>(
                valueListenable: widget.workspace.pendingMedicationRequests,
                builder: (context, pending, _) {
                  return _MedicationRequestsDashboardCard(
                    pendingCount: pending,
                    onTap: widget.workspace.openMedicationRequests,
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                decoration: PharmacistTheme.cardDec(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active, color: PharmacistTheme.gold, size: 22),
                        const SizedBox(width: 8),
                        Text(l10n.pharmacistQuickAlerts, style: PharmacistTheme.titleStyle(16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingAlerts)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: PharmacistTheme.gold, strokeWidth: 2)))
                    else if (_alerts.isEmpty)
                      Text(l10n.pharmacistNoCriticalAlerts, style: PharmacistTheme.bodyStyle())
                    else
                      ..._alerts.map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  a.severity == 'error' ? Icons.error_outline : Icons.info_outline,
                                  color: a.severity == 'error' ? PharmacistTheme.red : PharmacistTheme.orange,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(a.message, style: PharmacistTheme.bodyStyle(Colors.white70))),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.title, this.value, this.icon, this.accent);
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PharmacistTheme.cardDec(borderColor: accent),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: accent, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.urbanist(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(title, style: PharmacistTheme.bodyStyle(Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedicationRequestsDashboardCard extends StatelessWidget {
  const _MedicationRequestsDashboardCard({
    required this.pendingCount,
    required this.onTap,
  });

  final int pendingCount;
  final VoidCallback onTap;

  static const _badgeRed = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: PharmacistTheme.cardDec(borderColor: PharmacistTheme.gold).copyWith(
            gradient: LinearGradient(
              colors: [
                PharmacistTheme.gold.withValues(alpha: 0.08),
                const Color(0xFF1A1A1A),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Badge(
                  isLabelVisible: hasPending,
                  label: Text(
                    pendingCount > 99 ? '99+' : '$pendingCount',
                    style: GoogleFonts.urbanist(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: _badgeRed,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  offset: const Offset(8, -8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: PharmacistTheme.gold.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: PharmacistTheme.gold.withValues(alpha: 0.45)),
                    ),
                    child: const Icon(Icons.assignment_outlined, color: PharmacistTheme.gold, size: 28),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medication Requests',
                        style: PharmacistTheme.titleStyle(17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'طلبات الأدوية',
                        style: GoogleFonts.urbanist(
                          color: PharmacistTheme.gold.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasPending
                            ? '$pendingCount pending patient order${pendingCount == 1 ? '' : 's'} awaiting review'
                            : 'No pending orders — queue is clear',
                        style: PharmacistTheme.bodyStyle(
                          hasPending ? Colors.white70 : PharmacistTheme.greyText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: PharmacistTheme.gold.withValues(alpha: 0.9),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 3. Inventory Logs ──────────────────────────────────────────────────────

class PharmacistInventoryLogsPage extends StatefulWidget {
  const PharmacistInventoryLogsPage({super.key, required this.workspace});
  final PharmacyWorkspace workspace;

  @override
  State<PharmacistInventoryLogsPage> createState() => _PharmacistInventoryLogsPageState();
}

class _PharmacistInventoryLogsPageState extends State<PharmacistInventoryLogsPage> {
  List<InventoryLogEntry> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final logs = await widget.workspace.api.getInventoryLogs(widget.workspace.pharmacyId);
      if (mounted) setState(() { _logs = logs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PharmacistModuleSplit(
      header: _pageHeader('Inventory Logs', 'Audit trail — Dispense, Restock, Adjustment'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PharmacistTheme.gold))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _logs.length,
              itemBuilder: (_, i) {
                    final log = _logs[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: PharmacistTheme.cardDec(),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          _actionChip(log.action),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(log.drugName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                Text('${log.previousQty} → ${log.newQty} (${log.quantityChange >= 0 ? '+' : ''}${log.quantityChange})', style: PharmacistTheme.bodyStyle()),
                              ],
                            ),
                          ),
                          if (log.createdAt != null)
                            Text(DateFormat('MMM d, HH:mm').format(log.createdAt!), style: PharmacistTheme.bodyStyle()),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _actionChip(String action) {
    Color c = PharmacistTheme.gold;
    if (action == 'Dispense') c = PharmacistTheme.orange;
    if (action == 'Restock') c = PharmacistTheme.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(action, style: GoogleFonts.urbanist(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

// ─── 4. Dispensing Terminal ─────────────────────────────────────────────────

class PharmacistDispensingPage extends StatefulWidget {
  const PharmacistDispensingPage({super.key, required this.workspace});
  final PharmacyWorkspace workspace;

  @override
  State<PharmacistDispensingPage> createState() => _PharmacistDispensingPageState();
}

class _PharmacistDispensingPageState extends State<PharmacistDispensingPage> {
  List<PharmacyInventoryRow> _inventory = [];
  PharmacyInventoryRow? _selected;
  final _patientIdCtrl = TextEditingController();
  int _qty = 1;
  bool _loading = false;
  bool _processing = false;

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.workspace.api.listInventory(widget.workspace.pharmacyId);
      if (mounted) setState(() { _inventory = rows.where((r) => r.quantity > 0).toList(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dispense() async {
    if (_selected == null) return;
    setState(() => _processing = true);
    try {
      await widget.workspace.api.dispense(
        pharmacyId: widget.workspace.pharmacyId,
        drugId: _selected!.drugId,
        amount: _qty,
        patientUserId: _patientIdCtrl.text.trim().isEmpty ? null : _patientIdCtrl.text.trim(),
      );
      await widget.workspace.onRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispensed $_qty × ${_selected!.name}'), backgroundColor: const Color(0xFF2E7D32)),
      );
      setState(() { _selected = null; _qty = 1; });
      await _loadInventory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: PharmacistTheme.red));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PharmacistModuleScroll(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pageHeader('Dispensing Terminal', 'Rx-controlled drugs require patient ID — validated on server'),
            Container(
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: PharmacistTheme.cardDec(),
            padding: const EdgeInsets.all(24),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: PharmacistTheme.gold))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<PharmacyInventoryRow>(
                        initialValue: _selected,
                        dropdownColor: PharmacistTheme.card,
                        decoration: PharmacistTheme.inputDec('Select drug'),
                        items: _inventory
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text('${r.name} (stock: ${r.quantity})', style: const TextStyle(color: Colors.white)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selected = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _patientIdCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: PharmacistTheme.inputDec(
                          'Patient User ID (required for Rx drugs)',
                          hint: 'MongoDB users._id',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Quantity', style: PharmacistTheme.bodyStyle(Colors.white)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                            icon: const Icon(Icons.remove_circle_outline, color: PharmacistTheme.gold),
                          ),
                          Text('$_qty', style: PharmacistTheme.titleStyle(24)),
                          IconButton(
                            onPressed: _selected != null && _qty < _selected!.quantity ? () => setState(() => _qty++) : null,
                            icon: const Icon(Icons.add_circle_outline, color: PharmacistTheme.gold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _processing || _selected == null ? null : _dispense,
                        style: FilledButton.styleFrom(
                          backgroundColor: PharmacistTheme.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _processing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.point_of_sale),
                        label: Text(_processing ? 'Processing…' : 'Process Dispense'),
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

// ─── 5. Medication Requests ─────────────────────────────────────────────────

class PharmacistMedicationRequestsPage extends StatefulWidget {
  const PharmacistMedicationRequestsPage({super.key, required this.workspace});
  final PharmacyWorkspace workspace;

  @override
  State<PharmacistMedicationRequestsPage> createState() => _PharmacistMedicationRequestsPageState();
}

class _PharmacistMedicationRequestsPageState extends State<PharmacistMedicationRequestsPage> {
  List<MedicationRequestRow> _requests = [];
  bool _loading = true;
  String? _processingRequestId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.workspace.api.listMedicationRequests();
      if (mounted) setState(() { _requests = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _replaceRequest(MedicationRequestRow updated) {
    final idx = _requests.indexWhere((r) => r.id == updated.id);
    if (idx >= 0) {
      _requests[idx] = updated;
    } else {
      _requests.insert(0, updated);
    }
  }

  Future<void> _approveAndProcess(MedicationRequestRow req) async {
    setState(() => _processingRequestId = req.id);
    try {
      final updated = await widget.workspace.api.patchMedicationRequest(req.id, 'Approved');
      if (!mounted) return;
      setState(() {
        _processingRequestId = null;
        _replaceRequest(updated);
      });
      await widget.workspace.refreshPendingMedicationRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.transactionSubtitle ??
                'Payment processed — inventory deducted and wallet credited.',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } on MedicationRequestPatchException catch (e) {
      if (!mounted) return;
      setState(() {
        _processingRequestId = null;
        _replaceRequest(e.request);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: PharmacistTheme.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingRequestId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: PharmacistTheme.red),
      );
    }
  }

  Future<void> _rejectRequest(MedicationRequestRow req) async {
    setState(() => _processingRequestId = req.id);
    try {
      final updated = await widget.workspace.api.patchMedicationRequest(req.id, 'Rejected');
      if (!mounted) return;
      setState(() {
        _processingRequestId = null;
        _replaceRequest(updated);
      });
      await widget.workspace.refreshPendingMedicationRequests();
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingRequestId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: PharmacistTheme.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PharmacistModuleSplit(
      header: _pageHeader('Medication Requests', 'Patient order queue'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PharmacistTheme.gold))
          : _requests.isEmpty
              ? Center(
                  child: Text(
                    'No medication requests in queue.',
                    style: PharmacistTheme.bodyStyle(),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _requests.length,
                  itemBuilder: (_, i) => _requestCard(_requests[i]),
                ),
    );
  }

  Widget _requestCard(MedicationRequestRow r) {
    final isProcessing = _processingRequestId == r.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: PharmacistTheme.cardDec(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.medicationName,
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Qty: ${r.quantity}', style: PharmacistTheme.bodyStyle()),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isProcessing)
                _mockProcessingBadge()
              else
                _requestBadge(r),
            ],
          ),
          if (isProcessing) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: PharmacistTheme.gold),
                ),
                const SizedBox(width: 10),
                Text(
                  'Mock Processing…',
                  style: GoogleFonts.urbanist(color: PharmacistTheme.gold, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          if (!isProcessing && r.transactionSubtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              r.transactionSubtitle!,
              style: GoogleFonts.urbanist(
                color: PharmacistTheme.green.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (!isProcessing && r.isFailed && (r.failureReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r.failureReason!,
              style: GoogleFonts.urbanist(color: PharmacistTheme.red, fontSize: 12),
            ),
          ],
          if (r.status == 'Pending' && !isProcessing) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _approveAndProcess(r),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Approve & Process Payment'),
                  style: FilledButton.styleFrom(
                    backgroundColor: PharmacistTheme.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () => _rejectRequest(r),
                  child: const Text('Reject', style: TextStyle(color: PharmacistTheme.red)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mockProcessingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PharmacistTheme.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PharmacistTheme.gold.withValues(alpha: 0.35)),
      ),
      child: Text(
        'Processing',
        style: GoogleFonts.urbanist(color: PharmacistTheme.gold, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _requestBadge(MedicationRequestRow r) {
    Color c = PharmacistTheme.orange;
    if (r.isCompleted) c = PharmacistTheme.green;
    if (r.status == 'Partially Fulfilled') c = PharmacistTheme.gold;
    if (r.isFailed || r.status == 'Rejected') c = PharmacistTheme.red;
    if (r.status == 'Dispensed') c = PharmacistTheme.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        r.badgeLabel,
        style: GoogleFonts.urbanist(color: c, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

// ─── 6. Notifications ───────────────────────────────────────────────────────

class PharmacistNotificationsPage extends StatefulWidget {
  const PharmacistNotificationsPage({super.key, required this.workspace});
  final PharmacyWorkspace workspace;

  @override
  State<PharmacistNotificationsPage> createState() => _PharmacistNotificationsPageState();
}

class _PharmacistNotificationsPageState extends State<PharmacistNotificationsPage> {
  List<PharmacyAlert> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final alerts = await widget.workspace.api.getNotifications(widget.workspace.pharmacyId);
      if (mounted) setState(() { _alerts = alerts; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PharmacistModuleSplit(
      header: _pageHeader('System Notifications', 'Low stock, expiry, and patient tickets'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PharmacistTheme.gold))
          : RefreshIndicator(
              onRefresh: _load,
              color: PharmacistTheme.gold,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                itemCount: _alerts.length,
                itemBuilder: (_, i) {
                      final a = _alerts[i];
                      final icon = a.type.contains('stock') ? Icons.inventory_2 : Icons.notifications;
                      return ListTile(
                        tileColor: PharmacistTheme.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Icon(icon, color: PharmacistTheme.gold),
                        title: Text(a.message, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(a.type.replaceAll('_', ' '), style: PharmacistTheme.bodyStyle()),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─── 7. Analytics ───────────────────────────────────────────────────────────

class PharmacistAnalyticsPage extends StatefulWidget {
  const PharmacistAnalyticsPage({super.key, required this.workspace});
  final PharmacyWorkspace workspace;

  @override
  State<PharmacistAnalyticsPage> createState() => _PharmacistAnalyticsPageState();
}

class _PharmacistAnalyticsPageState extends State<PharmacistAnalyticsPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    widget.workspace.inventoryRevision.addListener(_onInventoryChanged);
  }

  @override
  void dispose() {
    widget.workspace.inventoryRevision.removeListener(_onInventoryChanged);
    super.dispose();
  }

  void _onInventoryChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.workspace.api.getAnalytics(widget.workspace.pharmacyId);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const PharmacistModuleLoading();
    final top = (_data?['topInStock'] as List<dynamic>?) ?? [];
    final low = (_data?['lowStock'] as List<dynamic>?) ?? [];
    final cats = (_data?['categoryStock'] as List<dynamic>?) ?? [];

    return PharmacistModuleScroll(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader('Analytic Reports', 'Stock distribution and risk metrics'),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _metricPanel('Top in stock', top.take(5).map((e) => '${e['name']}: ${e['quantity']}').join('\n')),
              _metricPanel('Low stock alerts', low.take(5).map((e) => '${e['name']}: ${e['quantity']}').join('\n')),
              _metricPanel('By category', cats.take(6).map((e) => '${e['category']}: ${e['totalQty']} units').join('\n')),
            ],
          ),
          const SizedBox(height: 24),
          ...cats.map((e) {
            final qty = (e['totalQty'] as num?)?.toDouble() ?? 0;
            final max = 100.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e['category']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (qty / max).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: const Color(0xFF2A2A2A),
                      color: PharmacistTheme.gold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        ),
      ),
    );
  }

  Widget _metricPanel(String title, String body) {
    return Container(
      width: 280,
      constraints: const BoxConstraints(minHeight: 140),
      decoration: PharmacistTheme.cardDec(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PharmacistTheme.titleStyle(16).copyWith(color: PharmacistTheme.gold)),
          const SizedBox(height: 10),
          Text(body.isEmpty ? 'No data' : body, style: PharmacistTheme.bodyStyle(Colors.white70)),
        ],
      ),
    );
  }
}

// ─── 8. Settings ────────────────────────────────────────────────────────────

class PharmacistSettingsPage extends StatefulWidget {
  const PharmacistSettingsPage({super.key, required this.workspace});
  final PharmacyWorkspace workspace;

  @override
  State<PharmacistSettingsPage> createState() => _PharmacistSettingsPageState();
}

class _PharmacistSettingsPageState extends State<PharmacistSettingsPage> {
  static const _defaultLat = 32.2211;
  static const _defaultLng = 35.2544;

  final _nameCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _mapSearchCtrl = TextEditingController();
  final _nominatim = NominatimService();
  LatLng? _mapMarker;
  double _latitude = _defaultLat;
  double _longitude = _defaultLng;
  bool _saving = false;
  bool _loading = true;
  bool _resolvingAddress = false;
  String _initialOperatingHours = '';
  int _hoursPickerGeneration = 0;

  @override
  void initState() {
    super.initState();
    _latitude = _defaultLat;
    _longitude = _defaultLng;
    _mapMarker = const LatLng(_defaultLat, _defaultLng);
    _loadSignupData();
  }

  @override
  void dispose() {
    _nominatim.dispose();
    _nameCtrl.dispose();
    _hoursCtrl.dispose();
    _addressCtrl.dispose();
    _mapSearchCtrl.dispose();
    super.dispose();
  }

  bool _isCoordinateLabel(String label) {
    final t = label.trim();
    return t.startsWith('Lat ') || RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+').hasMatch(t);
  }

  Future<void> _resolveAddressForPoint(LatLng point, {String? hint}) async {
    if (hint != null && hint.trim().isNotEmpty && !_isCoordinateLabel(hint)) {
      if (mounted) setState(() => _addressCtrl.text = hint.trim());
      return;
    }
    setState(() => _resolvingAddress = true);
    try {
      final resolved = await _nominatim.reverseGeocode(point);
      if (!mounted) return;
      setState(() {
        _addressCtrl.text = (resolved != null && resolved.trim().isNotEmpty)
            ? resolved.trim()
            : 'Rafidia, Nablus';
      });
    } finally {
      if (mounted) setState(() => _resolvingAddress = false);
    }
  }

  Future<void> _loadSignupData() async {
    setState(() => _loading = true);
    try {
      final profile = await widget.workspace.api.getProfile();
      if (!mounted) return;
      _applyProfile(profile);
    } catch (_) {
      if (mounted) {
        _nameCtrl.text = widget.workspace.stats.pharmacyName;
        _latitude = _defaultLat;
        _longitude = _defaultLng;
        _mapMarker = const LatLng(_defaultLat, _defaultLng);
        _addressCtrl.text = 'Rafidia, Nablus';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProfile(Map<String, dynamic> profile) {
    _nameCtrl.text = profile['pharmacyName']?.toString().trim().isNotEmpty == true
        ? profile['pharmacyName'].toString()
        : widget.workspace.stats.pharmacyName;
    final hours = profile['operatingHours']?.toString() ?? '';
    _hoursCtrl.text = hours;
    _initialOperatingHours = hours;
    _hoursPickerGeneration++;
    final lat = _parseCoord(profile['latitude'], _defaultLat);
    final lng = _parseCoord(profile['longitude'], _defaultLng);
    _latitude = lat;
    _longitude = lng;
    _mapMarker = LatLng(lat, lng);

    final storedAddress = profile['address']?.toString().trim() ?? '';
    if (storedAddress.isNotEmpty) {
      _addressCtrl.text = storedAddress;
    } else {
      _resolveAddressForPoint(_mapMarker!);
    }
  }

  double _parseCoord(dynamic value, double fallback) {
    if (value == null) return fallback;
    final n = value is num ? value.toDouble() : double.tryParse(value.toString());
    return n != null && n.isFinite ? n : fallback;
  }

  void _onMapPositionChanged(LatLng point, String label) {
    setState(() {
      _mapMarker = point;
      _latitude = point.latitude;
      _longitude = point.longitude;
    });
    _resolveAddressForPoint(point, hint: label);
  }

  LatLng get _mapCenter => _mapMarker ?? const LatLng(_defaultLat, _defaultLng);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final lat = _mapMarker?.latitude ?? _latitude;
      final lng = _mapMarker?.longitude ?? _longitude;

      await widget.workspace.api.updatePharmacyProfile(widget.workspace.pharmacyId, {
        'name': _nameCtrl.text.trim(),
        'operatingHours': _hoursCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'latitude': lat,
        'longitude': lng,
      });
      await widget.workspace.onRefresh();
      if (mounted) {
        final addrPreview = _addressCtrl.text.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              addrPreview.isEmpty ? 'Settings saved' : 'Location saved · $addrPreview',
              style: const TextStyle(color: Colors.black),
            ),
            backgroundColor: PharmacistTheme.gold,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildFormCard({bool scrollable = true}) {
    final fields = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: PharmacistTheme.inputDec('Pharmacy Name', hint: 'Store name from registration'),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          PharmacyOperatingHoursPicker(
            key: ValueKey(_hoursPickerGeneration),
            initialValue: _initialOperatingHours,
            usePharmacistTheme: true,
            onChanged: (formatted) => _hoursCtrl.text = formatted,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            readOnly: true,
            maxLines: 3,
            minLines: 2,
            decoration: PharmacistTheme.inputDec(
              'Pharmacy Address / Location Name',
              hint: 'Select on map or search — updates automatically',
              prefix: const Icon(Icons.place_outlined, color: PharmacistTheme.gold, size: 22),
              suffix: _resolvingAddress
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: PharmacistTheme.gold)),
                    )
                  : null,
            ),
            style: const TextStyle(color: Colors.white, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            'Coordinates update in the background when you move the map pin.',
            style: PharmacistTheme.bodyStyle(Colors.white54),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: PharmacistTheme.gold,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('Save Settings'),
          ),
          const SizedBox(height: 8),
        ],
    );

    return Container(
      decoration: PharmacistTheme.cardDec(),
      clipBehavior: Clip.antiAlias,
      child: scrollable
          ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: fields,
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: fields,
            ),
    );
  }

  Widget _buildMapPanel() {
    return Container(
      decoration: PharmacistTheme.cardDec(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pharmacy Location', style: PharmacistTheme.titleStyle(17).copyWith(color: PharmacistTheme.gold)),
          const SizedBox(height: 6),
          Text(
            'Search a place, tap the map, or drag the pin — the address field updates automatically.',
            style: PharmacistTheme.bodyStyle(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PharmacyLocationPicker(
              settingsOverlay: true,
              marker: _mapMarker,
              locationConfirmed: true,
              mapCenter: _mapCenter,
              searchCityName: 'Nablus',
              searchController: _mapSearchCtrl,
              onMarkerChanged: _onMapPositionChanged,
              onLocationConfirmed: () {},
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const PharmacistModuleLoading();

    return PharmacistModuleScroll(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pageHeader('Pharmacy Settings', 'Review and update your registered pharmacy details'),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final useRow = constraints.maxWidth >= 900;
                if (!useRow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFormCard(scrollable: false),
                      const SizedBox(height: 24),
                      SizedBox(height: 480, child: _buildMapPanel()),
                    ],
                  );
                }
                return SizedBox(
                  height: 620,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 4, child: _buildFormCard(scrollable: true)),
                      const SizedBox(width: 24),
                      Expanded(flex: 5, child: _buildMapPanel()),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 9. Profile ─────────────────────────────────────────────────────────────

class PharmacistProfilePage extends StatefulWidget {
  const PharmacistProfilePage({super.key, required this.workspace});
  final PharmacyWorkspace workspace;

  @override
  State<PharmacistProfilePage> createState() => _PharmacistProfilePageState();
}

class _PharmacistProfilePageState extends State<PharmacistProfilePage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _pharmacyDisplayCtrl = TextEditingController();

  String _profileImage = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _licenseCtrl.dispose();
    _pharmacyDisplayCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await widget.workspace.api.getProfile();
      if (!mounted) return;
      _nameCtrl.text = p['name']?.toString() ?? '';
      _emailCtrl.text = p['email']?.toString() ?? '';
      _phoneCtrl.text = p['phone']?.toString() ?? '';
      _licenseCtrl.text = p['licenseNumber']?.toString() ?? '';
      _profileImage = p['profileImageUrl']?.toString() ?? '';
      _pharmacyDisplayCtrl.text = p['pharmacyName']?.toString() ?? widget.workspace.stats.pharmacyName;
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final img = await pickPharmacistProfilePhoto();
    if (img != null && mounted) setState(() => _profileImage = img);
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email are required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.workspace.api.updatePharmacistProfile(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        profileImageUrl: _profileImage.isNotEmpty ? _profileImage : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated', style: TextStyle(color: Colors.black)),
            backgroundColor: PharmacistTheme.gold,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const PharmacistModuleLoading();

    return PharmacistModuleScroll(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pageHeader('Pharmacist Profile', 'Personal identity and verified credentials'),
            Container(
              constraints: const BoxConstraints(maxWidth: 520),
              decoration: PharmacistTheme.cardDec(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PharmacistProfilePhotoPicker(
                    imageData: _profileImage,
                    onPick: _pickPhoto,
                  ),
                  pharmacistPhotoHint(),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: PharmacistTheme.inputDec('Full Name', prefix: const Icon(Icons.person_outline, color: PharmacistTheme.gold, size: 20)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: PharmacistTheme.inputDec('Email', prefix: const Icon(Icons.email_outlined, color: PharmacistTheme.gold, size: 20)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: PharmacistTheme.inputDec('Phone Number', prefix: const Icon(Icons.phone_outlined, color: PharmacistTheme.gold, size: 20)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pharmacyDisplayCtrl,
                    readOnly: true,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    decoration: PharmacistTheme.inputDec('Linked Pharmacy', prefix: const Icon(Icons.local_pharmacy_outlined, color: PharmacistTheme.gold, size: 20)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _licenseCtrl,
                    readOnly: true,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                    decoration: PharmacistTheme.inputDec(
                      'Pharmacy License Number',
                      hint: 'Verified at registration',
                      prefix: const Icon(Icons.verified_user_outlined, color: PharmacistTheme.gold, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'License is verified and cannot be changed here.',
                    style: PharmacistTheme.bodyStyle(Colors.white54),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _saveProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: PharmacistTheme.gold,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Update Profile'),
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
