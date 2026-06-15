import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../widgets/responsive_layout.dart';
import '../data/pharmacy_inventory_api.dart';
import 'pharmacist_layout.dart';
import 'pharmacist_theme.dart';

/// Inventory Management — bounded scroll + live search + add/edit dialogs.
class PharmacistInventoryPage extends StatefulWidget {
  const PharmacistInventoryPage({super.key, required this.workspace});

  final PharmacyWorkspace workspace;

  @override
  State<PharmacistInventoryPage> createState() => _PharmacistInventoryPageState();
}

class _PharmacistInventoryPageState extends State<PharmacistInventoryPage> {
  static const _fallbackCategories = [
    'Painkiller',
    'Antibiotic',
    'Diabetes',
    'Cardiovascular',
    'Cholesterol',
    'Gastrointestinal',
    'Hypertension',
    'Neurology',
    'Thyroid',
    'Antifungal',
    'Other',
  ];

  final _searchController = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  List<PharmacyInventoryRow> _allDrugs = [];
  List<String> _categories = List.from(_fallbackCategories);
  bool _loading = true;
  bool _saving = false;

  String searchQuery = '';

  List<PharmacyInventoryRow> get _filteredDrugs {
    if (searchQuery.isEmpty) return _allDrugs;
    return _allDrugs.where((drug) {
      final name = drug.name.toLowerCase();
      final category = drug.category.toLowerCase();
      return name.startsWith(searchQuery) || category.contains(searchQuery);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final drugs = await widget.workspace.api.listGlobalDrugs();
      final cats = drugs.map((d) => d['category']?.toString() ?? '').where((c) => c.isNotEmpty).toSet().toList()..sort();
      if (!mounted || cats.isEmpty) return;
      setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.workspace.api.listInventory(widget.workspace.pharmacyId, limit: 200);
      if (!mounted) return;
      setState(() {
        _allDrugs = rows;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() => searchQuery = value.trim().toLowerCase());
  }

  Future<void> _afterMutation({Map<String, dynamic>? apiResponse, String? message}) async {
    await widget.workspace.refreshAfterInventoryChange(apiResponse: apiResponse);
    await _load();
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.urbanist(color: Colors.black)),
          backgroundColor: PharmacistTheme.gold,
        ),
      );
    }
  }

  void _snackError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString(), style: PharmacistTheme.bodyStyle(Colors.white)), backgroundColor: PharmacistTheme.red),
    );
  }

  Future<void> _showAddNewDrugDialog() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '10');
    final priceCtrl = TextEditingController(text: '15.00');
    final mfrCtrl = TextEditingController(text: 'Rafeeq Pharma');
    var category = _categories.first;
    var expiry = DateTime.now().add(const Duration(days: 365));
    var requiresPrescription = false;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dl10n = ctx.l10n;
          return AlertDialog(
            backgroundColor: PharmacistTheme.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: PharmacistTheme.gold.withValues(alpha: 0.35))),
            title: Row(
              children: [
                const Icon(Icons.add_circle_outline, color: PharmacistTheme.gold),
                const SizedBox(width: 10),
                Text(dl10n.pharmacistAddNewDrug, style: PharmacistTheme.titleStyle(18)),
              ],
            ),
            content: SizedBox(
              width: RafeeqResponsive.of(ctx).dialogContentWidth(desktopMax: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: PharmacistTheme.inputDec(dl10n.pharmacistDrugName),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: PharmacistTheme.inputDec(dl10n.pharmacistCategory),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: category,
                          dropdownColor: const Color(0xFF252525),
                          style: const TextStyle(color: Colors.white),
                          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setDialogState(() => category = v ?? category),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      decoration: PharmacistTheme.inputDec(dl10n.pharmacistStockQty),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      decoration: PharmacistTheme.inputDec(dl10n.pharmacistPrice),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mfrCtrl,
                      decoration: PharmacistTheme.inputDec(dl10n.pharmacistManufacturer),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: expiry,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                          builder: (c, child) => Theme(
                            data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: PharmacistTheme.gold)),
                            child: child!,
                          ),
                        );
                        if (picked != null) setDialogState(() => expiry = picked);
                      },
                      child: InputDecorator(
                        decoration: PharmacistTheme.inputDec(dl10n.pharmacistExpiryDate, suffix: const Icon(Icons.calendar_today, color: PharmacistTheme.gold, size: 20)),
                        child: Text(_dateFmt.format(expiry), style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PharmacistTheme.gold.withValues(alpha: 0.2)),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dl10n.pharmacistRequiresPrescription,
                              style: GoogleFonts.urbanist(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'خاضع للرقابة الطبية',
                              style: GoogleFonts.urbanist(
                                color: PharmacistTheme.gold.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          dl10n.pharmacistRxRequiredHint,
                          style: GoogleFonts.urbanist(color: Colors.white38, fontSize: 11, height: 1.35),
                        ),
                        value: requiresPrescription,
                        activeThumbColor: PharmacistTheme.gold,
                        activeTrackColor: PharmacistTheme.gold.withValues(alpha: 0.45),
                        inactiveThumbColor: Colors.grey.shade600,
                        inactiveTrackColor: Colors.white12,
                        onChanged: (v) => setDialogState(() => requiresPrescription = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(dl10n.nurseCancel)),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                style: FilledButton.styleFrom(backgroundColor: PharmacistTheme.gold, foregroundColor: Colors.black),
                child: Text(dl10n.pharmacistAddToInventory),
              ),
            ],
          );
        },
      ),
    );

    if (submitted != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final res = await widget.workspace.api.createNewInventoryDrug(
        widget.workspace.pharmacyId,
        name: nameCtrl.text.trim(),
        category: category,
        quantity: int.tryParse(qtyCtrl.text) ?? 0,
        price: double.tryParse(priceCtrl.text) ?? 0,
        manufacturer: mfrCtrl.text.trim().isEmpty ? 'Rafeeq Pharma' : mfrCtrl.text.trim(),
        expiryDate: _dateFmt.format(expiry),
        requiresPrescription: requiresPrescription,
      );
      await _afterMutation(apiResponse: res, message: 'Drug added successfully.');
    } catch (e) {
      _snackError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showEditStockDialog(PharmacyInventoryRow row) async {
    var qty = row.quantity;
    final priceCtrl = TextEditingController(text: row.price.toStringAsFixed(2));
    final mfrCtrl = TextEditingController(text: row.manufacturer);
    final qtyCtrl = TextEditingController(text: row.quantity.toString());
    var expiry = row.expiryDate ?? DateTime.now().add(const Duration(days: 180));

    void syncQtyFromField(void Function(void Function()) setDialogState) {
      final parsed = int.tryParse(qtyCtrl.text);
      if (parsed != null && parsed >= 0) {
        setDialogState(() => qty = parsed);
      }
    }

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: PharmacistTheme.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: PharmacistTheme.gold.withValues(alpha: 0.35))),
            title: Row(
              children: [
                const Icon(Icons.edit_outlined, color: PharmacistTheme.gold),
                const SizedBox(width: 10),
                Expanded(child: Text('Edit Stock — ${row.name}', style: PharmacistTheme.titleStyle(17))),
              ],
            ),
            content: SizedBox(
              width: RafeeqResponsive.of(ctx).dialogContentWidth(desktopMax: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${row.category} · ${row.status}', style: PharmacistTheme.bodyStyle()),
                  const SizedBox(height: 16),
                  Text('Stock quantity', style: PharmacistTheme.bodyStyle(Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF2A2A2A), foregroundColor: PharmacistTheme.gold),
                        onPressed: qty > 0
                            ? () {
                                setDialogState(() {
                                  qty -= 1;
                                  qtyCtrl.text = qty.toString();
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextField(
                            controller: qtyCtrl,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: PharmacistTheme.inputDec('Qty'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            onChanged: (_) => syncQtyFromField(setDialogState),
                          ),
                        ),
                      ),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: PharmacistTheme.gold, foregroundColor: Colors.black),
                        onPressed: () {
                          setDialogState(() {
                            qty += 1;
                            qtyCtrl.text = qty.toString();
                          });
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    decoration: PharmacistTheme.inputDec('Price'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mfrCtrl,
                    decoration: PharmacistTheme.inputDec('Manufacturer'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: expiry,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                        builder: (c, child) => Theme(
                          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: PharmacistTheme.gold)),
                          child: child!,
                        ),
                      );
                      if (picked != null) setDialogState(() => expiry = picked);
                    },
                    child: InputDecorator(
                      decoration: PharmacistTheme.inputDec('Expiry Date', suffix: const Icon(Icons.calendar_today, color: PharmacistTheme.gold, size: 20)),
                      child: Text(_dateFmt.format(expiry), style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: PharmacistTheme.gold, foregroundColor: Colors.black),
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    if (submitted != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final res = await widget.workspace.api.updateInventory(
        widget.workspace.pharmacyId,
        row.drugId,
        quantity: int.tryParse(qtyCtrl.text) ?? qty,
        price: double.tryParse(priceCtrl.text),
        manufacturer: mfrCtrl.text.trim(),
        expiryDate: _dateFmt.format(expiry),
      );
      await _afterMutation(apiResponse: res, message: 'Stock updated.');
    } catch (e) {
      _snackError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRow(PharmacyInventoryRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PharmacistTheme.card,
        title: const Text('Remove from inventory?', style: TextStyle(color: Colors.white)),
        content: Text('Delete ${row.name} from this pharmacy stock?', style: PharmacistTheme.bodyStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: PharmacistTheme.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    try {
      final res = await widget.workspace.api.deleteInventory(widget.workspace.pharmacyId, row.drugId);
      await _afterMutation(apiResponse: res, message: 'Removed from inventory.');
    } catch (e) {
      _snackError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filtered = _filteredDrugs;

    return PharmacistModuleSplit(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _pageHeader(l10n.pharmacistNavInventoryManagement, l10n.pharmacistInventorySubtitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: PharmacistTheme.inputDec(
                      l10n.pharmacistSearchDrugs,
                      hint: l10n.pharmacistSearchHint,
                      prefix: const Icon(Icons.search, color: PharmacistTheme.gold),
                      suffix: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: Colors.grey.shade500, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _showAddNewDrugDialog,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.add, size: 20),
                  label: Text(l10n.pharmacistAddNewDrugBtn),
                  style: FilledButton.styleFrom(
                    backgroundColor: PharmacistTheme.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              children: [
                Text(
                  searchQuery.isEmpty
                      ? l10n.pharmacistShowingAll(_allDrugs.length)
                      : l10n.pharmacistShowingMatches(filtered.length, _allDrugs.length),
                  style: PharmacistTheme.bodyStyle(),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.pharmacistRefreshCatalog,
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, color: PharmacistTheme.gold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PharmacistTheme.gold))
          : filtered.isEmpty
              ? Center(
                  child: Text(
                    searchQuery.isEmpty ? l10n.pharmacistNoInventory : l10n.pharmacistNoDrugsMatch(searchQuery),
                    style: PharmacistTheme.bodyStyle(),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: DecoratedBox(
                    decoration: PharmacistTheme.cardDec(borderColor: Colors.white24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final tableWidth = constraints.maxWidth > 1040 ? constraints.maxWidth : 1040.0;
                          return Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                height: constraints.maxHeight,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const _InventoryTableHeader(),
                                    Expanded(
                                      child: Scrollbar(
                                        thumbVisibility: true,
                                        child: ListView.builder(
                                          itemCount: filtered.length,
                                          itemBuilder: (context, index) {
                                            final row = filtered[index];
                                            return _InventoryDataRow(
                                              row: row,
                                              dateFmt: _dateFmt,
                                              onEdit: () => _showEditStockDialog(row),
                                              onDelete: () => _deleteRow(row),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
    );
  }

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
}

class _InventoryTableHeader extends StatelessWidget {
  const _InventoryTableHeader();

  static const _headerStyle = TextStyle(
    color: PharmacistTheme.gold,
    fontWeight: FontWeight.w700,
    fontSize: 13,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252525),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: const Row(
        children: [
          SizedBox(width: 200, child: Text('Drug Name', style: _headerStyle)),
          SizedBox(width: 140, child: Text('Category', style: _headerStyle)),
          SizedBox(width: 64, child: Text('Stock', style: _headerStyle)),
          SizedBox(width: 72, child: Text('Price', style: _headerStyle)),
          SizedBox(width: 120, child: Text('Manufacturer', style: _headerStyle)),
          SizedBox(width: 100, child: Text('Expiry', style: _headerStyle)),
          SizedBox(width: 110, child: Text('Status', style: _headerStyle)),
          SizedBox(width: 88, child: Text('Actions', style: _headerStyle)),
        ],
      ),
    );
  }
}

class _InventoryDataRow extends StatelessWidget {
  const _InventoryDataRow({
    required this.row,
    required this.dateFmt,
    required this.onEdit,
    required this.onDelete,
  });

  final PharmacyInventoryRow row;
  final DateFormat dateFmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (row.requiresPrescription) ...[
                  const SizedBox(height: 4),
                  _prescriptionRequiredBadge(compact: true),
                ],
              ],
            ),
          ),
          SizedBox(width: 140, child: Text(row.category, style: PharmacistTheme.bodyStyle(), maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 64, child: Text(row.quantity.toString(), style: const TextStyle(color: Colors.white, fontSize: 13))),
          SizedBox(width: 72, child: Text(row.price.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 13))),
          SizedBox(
            width: 120,
            child: Text(row.manufacturer, style: PharmacistTheme.bodyStyle(), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 100,
            child: Text(
              row.expiryDate != null ? dateFmt.format(row.expiryDate!) : '—',
              style: PharmacistTheme.bodyStyle(),
            ),
          ),
          SizedBox(width: 110, child: _inventoryStatusBadge(row.status)),
          SizedBox(
            width: 88,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: PharmacistTheme.gold, size: 20),
                  onPressed: onEdit,
                  tooltip: 'Edit stock',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: PharmacistTheme.red, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft amber/red accent for controlled (Rx-required) catalog items.
Widget _prescriptionRequiredBadge({bool compact = false}) {
  const accent = Color(0xFFE8A54B);
  const accentDeep = Color(0xFFC75B39);
  return Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [accent.withValues(alpha: 0.22), accentDeep.withValues(alpha: 0.18)],
      ),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: accentDeep.withValues(alpha: 0.55)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.receipt_long, size: compact ? 12 : 14, color: accent),
        const SizedBox(width: 4),
        Text(
          compact ? 'Rx' : 'Prescription Required',
          style: GoogleFonts.urbanist(
            color: accent,
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

Widget _inventoryStatusBadge(String status) {
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
    child: Text(
      status,
      style: GoogleFonts.urbanist(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}
