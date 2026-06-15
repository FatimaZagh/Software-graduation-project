import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../billing/models/doctor_billing_profile.dart';
import '../data/doctor_portal_api.dart';

const Color _kWorkspaceBlack = Color(0xFF0A0F0D);
const Color _kFieldFill = Color(0xFF161A18);
const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE8A3);
const Color _kGoldDeep = Color(0xFFB8860B);

class _ServiceRow {
  _ServiceRow({required this.key, required this.name, required this.price, required this.enabled});

  final String key;
  final TextEditingController name;
  final TextEditingController price;
  bool enabled;

  void dispose() {
    name.dispose();
    price.dispose();
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name.text.trim(),
        'price': num.tryParse(price.text.trim()) ?? 0,
        'enabled': enabled,
      };
}

/// Doctor Clinic & Services — consultation fee and specialized service pricing.
class DoctorClinicServicesScreen extends StatefulWidget {
  const DoctorClinicServicesScreen({super.key, required this.doctorUserId});

  final String doctorUserId;

  @override
  State<DoctorClinicServicesScreen> createState() => _DoctorClinicServicesScreenState();
}

class _DoctorClinicServicesScreenState extends State<DoctorClinicServicesScreen> {
  final _clinicName = TextEditingController();
  final _consultationFee = TextEditingController();
  final List<_ServiceRow> _services = [];
  bool _loading = true;
  bool _saving = false;
  bool _hasInternalPharmacy = false;
  String? _error;

  @override
  void dispose() {
    _clinicName.dispose();
    _consultationFee.dispose();
    for (final s in _services) {
      s.dispose();
    }
    super.dispose();
  }

  InputDecoration _dec(String label, {bool readOnly = false}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _kGold.withValues(alpha: readOnly ? 0.35 : 0.65)),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _kGold.withValues(alpha: readOnly ? 0.45 : 0.85)),
      filled: true,
      fillColor: readOnly ? const Color(0xFF121614) : _kFieldFill,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: _kGold, width: readOnly ? 1 : 1.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await DoctorPortalApi.getClinicServices(widget.doctorUserId);
      if (!mounted) return;
      for (final s in _services) {
        s.dispose();
      }
      _services.clear();
      _clinicName.text = cfg['clinicName']?.toString() ?? '';
      final resolvedFee = DoctorBillingProfile.parseConsultationFee(cfg['consultationFee']);
      _consultationFee.text = resolvedFee.truncateToDouble() == resolvedFee
          ? '${resolvedFee.toInt()}'
          : resolvedFee.toStringAsFixed(2);
      _hasInternalPharmacy = cfg['hasInternalPharmacy'] == true;
      final list = cfg['specializedServices'] as List<dynamic>? ?? [];
      for (final raw in list) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        _services.add(
          _ServiceRow(
            key: m['key']?.toString() ?? m['name']?.toString() ?? '',
            name: TextEditingController(text: m['name']?.toString() ?? ''),
            price: TextEditingController(text: '${m['price'] ?? ''}'),
            enabled: m['enabled'] != false,
          ),
        );
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final fee = num.tryParse(_consultationFee.text.trim());
    if (fee == null || fee <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter a valid consultation fee (ILS)', style: GoogleFonts.urbanist(color: _kGoldLight)),
          backgroundColor: const Color(0xFF1A1510),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await DoctorPortalApi.putClinicServices(widget.doctorUserId, {
        'clinicName': _clinicName.text.trim(),
        'consultationFee': fee,
        'specializedServices': [for (final s in _services) s.toJson()],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Clinic & services saved', style: GoogleFonts.urbanist(color: _kGoldLight)),
          backgroundColor: const Color(0xFF1A1510),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addService() {
    setState(() {
      _services.add(
        _ServiceRow(
          key: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: TextEditingController(),
          price: TextEditingController(text: '0'),
          enabled: true,
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final title = isAr ? 'العيادة والخدمات' : 'Clinic & Services';
    final clinicLabel = isAr ? 'اسم العيادة' : 'Clinic name';
    final feeLabel = l10n.doctorFieldFee;
    final servicesTitle = isAr ? 'أسعار الخدمات المتخصصة' : 'Specialized service pricing';
    final pharmacyNote = isAr
        ? 'الصيدلية الداخلية مفعّلة — مبيعات الوصفات تُضاف لإيرادات العيادة.'
        : 'Internal pharmacy enabled — e-prescription sales feed clinic revenue.';

    return Scaffold(
      backgroundColor: _kWorkspaceBlack,
      appBar: AppBar(
        backgroundColor: _kWorkspaceBlack,
        foregroundColor: _kGoldLight,
        elevation: 0,
        title: Text(title, style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kGold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                        TextButton(onPressed: _load, child: Text(l10n.doctorRetry, style: const TextStyle(color: _kGold))),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isAr
                            ? 'تُستخدم هذه الأسعار عند إنهاء الجلسة وفي لوحة الفوترة.'
                            : 'These prices drive session billing and the admin ledger.',
                        style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _clinicName,
                        readOnly: true,
                        style: GoogleFonts.urbanist(color: Colors.white54, fontSize: 15),
                        decoration: _dec(clinicLabel, readOnly: true),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _consultationFee,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        style: GoogleFonts.urbanist(color: Colors.white, fontSize: 15),
                        cursorColor: _kGold,
                        decoration: _dec(feeLabel),
                      ),
                      if (_hasInternalPharmacy) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kFieldFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kGold.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.local_pharmacy_outlined, color: _kGold.withValues(alpha: 0.85), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(pharmacyNote, style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 12.5)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              servicesTitle,
                              style: GoogleFonts.urbanist(color: _kGold, fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addService,
                            icon: const Icon(Icons.add, color: _kGoldLight, size: 18),
                            label: Text(isAr ? 'إضافة' : 'Add', style: GoogleFonts.urbanist(color: _kGoldLight)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._services.map((s) => _serviceCard(s, isAr)),
                      const SizedBox(height: 24),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _saving ? null : _save,
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [_kGoldLight, _kGold, _kGoldDeep, _kGold],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: _saving
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: _kWorkspaceBlack),
                                    )
                                  : Text(
                                      isAr ? 'حفظ الإعدادات' : 'Save configuration',
                                      style: GoogleFonts.urbanist(color: _kWorkspaceBlack, fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _serviceCard(_ServiceRow row, bool isAr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGold.withValues(alpha: row.enabled ? 0.45 : 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: row.enabled,
                activeColor: _kGold,
                onChanged: (v) => setState(() => row.enabled = v ?? false),
              ),
              Expanded(
                child: TextFormField(
                  controller: row.name,
                  enabled: row.enabled,
                  style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
                  decoration: _dec(isAr ? 'اسم الخدمة' : 'Service name'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: row.price,
            enabled: row.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            style: GoogleFonts.urbanist(color: Colors.white, fontSize: 14),
            decoration: _dec(isAr ? 'السعر (شيكل)' : 'Price (ILS)'),
          ),
        ],
      ),
    );
  }
}
