import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../tenant_state.dart';
import '../../auth/data/pharmacy_cities.dart';
import '../data/patient_portal_api.dart';
import 'patient_locale_text.dart';
import 'patient_mock_payment_sheet.dart';
import 'patient_nearby_pharmacies_sheet.dart';
import 'patient_theme.dart';

/// Scenario A/B purchase routing sheet for a single medication.
Future<bool?> showPatientPharmacyPurchaseSheet(
  BuildContext context, {
  required String patientUserId,
  required String drugId,
  required String drugName,
  required bool requiresPrescription,
  String? prescriptionId,
  String? medicationId,
  int? maxQuantity,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: kPatientSheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => PatientPharmacyPurchaseSheet(
      patientUserId: patientUserId,
      drugId: drugId,
      drugName: drugName,
      requiresPrescription: requiresPrescription,
      prescriptionId: prescriptionId,
      medicationId: medicationId ?? drugId,
      maxQuantity: maxQuantity,
    ),
  );
}

class PatientPharmacyPurchaseSheet extends StatefulWidget {
  const PatientPharmacyPurchaseSheet({
    super.key,
    required this.patientUserId,
    required this.drugId,
    required this.drugName,
    required this.requiresPrescription,
    this.prescriptionId,
    this.medicationId,
    this.maxQuantity,
  });

  final String patientUserId;
  final String drugId;
  final String drugName;
  final bool requiresPrescription;
  final String? prescriptionId;
  final String? medicationId;
  final int? maxQuantity;

  @override
  State<PatientPharmacyPurchaseSheet> createState() => _PatientPharmacyPurchaseSheetState();
}

class _PatientPharmacyPurchaseSheetState extends State<PatientPharmacyPurchaseSheet> {
  Map<String, dynamic>? _routing;
  bool _loading = true;
  bool _busy = false;
  int _qty = 1;
  String? _error;

  static const _rxBlockEn =
      'This medication requires a valid prescription from a licensed physician.';
  static const _rxBlockAr = 'يتطلب هذا الدواء وصفة طبية صالحة من طبيب مرخّص.';

  @override
  void initState() {
    super.initState();
    _loadRouting();
  }

  LatLng _searchOrigin() {
    final internal = _routing?['internalPharmacy'];
    if (internal is Map) {
      final lat = internal['latitude'];
      final lng = internal['longitude'];
      if (lat != null && lng != null) {
        return LatLng((lat as num).toDouble(), (lng as num).toDouble());
      }
    }
    return kPharmacyCities.first.center;
  }

  String? _excludeInternalPharmacyId() {
    final internal = _routing?['internalPharmacy'];
    if (internal is Map) {
      return internal['pharmacyId']?.toString();
    }
    return null;
  }

  int get _internalStock {
    final q = _routing?['internalStockQuantity'];
    if (q is num) return q.toInt();
    final internal = _routing?['internalPharmacy'];
    if (internal is Map && internal['stockQuantity'] is num) {
      return (internal['stockQuantity'] as num).toInt();
    }
    return _routing?['internalInStock'] == true ? 1 : 0;
  }

  /// True when the active clinic/org routing includes a usable internal pharmacy.
  bool get _hasClinicPharmacy {
    final routing = _routing;
    if (routing == null) return false;
    if (routing['hasInternalPharmacy'] == true) {
      final internal = routing['internalPharmacy'];
      if (internal is Map) {
        final id = internal['pharmacyId']?.toString().trim() ?? '';
        if (id.isNotEmpty) return true;
      }
    }
    if (routing['scenario']?.toString() == 'A' && routing['internalPharmacy'] is Map) {
      final id = (routing['internalPharmacy'] as Map)['pharmacyId']?.toString().trim() ?? '';
      return id.isNotEmpty;
    }
    return false;
  }

  Map<String, dynamic>? get _internalPharmacyMap {
    final internal = _routing?['internalPharmacy'];
    if (internal is Map) return Map<String, dynamic>.from(internal);
    return null;
  }

  Future<void> _loadRouting() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final origin = kPharmacyCities.first.center;
      final clinicId = TenantState.instance.preferredClinicId.trim();
      final data = await PatientPortalApi.getPharmacyRouting(
        widget.patientUserId,
        drugId: widget.drugId,
        clinicId: clinicId.isEmpty ? null : clinicId,
        lat: origin.latitude,
        lng: origin.longitude,
      );
      if (mounted) setState(() => _routing = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _purchase(String pharmacyId, {required bool isArabic}) async {
    if (pharmacyId.isEmpty || _busy) return;

    if (widget.requiresPrescription &&
        (widget.prescriptionId == null || widget.prescriptionId!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'يتطلب هذا الدواء وصفة طبية — اشترِ من شاشة الوصفات فقط.'
                : 'Prescription required — purchase only from My Prescriptions.',
          ),
          backgroundColor: Colors.redAccent.shade700,
        ),
      );
      return;
    }

    final payment = await showPatientMockPaymentSheet(
      context,
      patientUserId: widget.patientUserId,
      drugName: widget.drugName,
      quantity: _qty,
    );
    if (payment == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final locale = Localizations.localeOf(context).languageCode;
      await PatientPortalApi.purchaseMedication(
        widget.patientUserId,
        drugId: widget.drugId,
        quantity: _qty,
        pharmacyId: pharmacyId,
        paymentStatus: payment.paymentStatus,
        cardLastFour: payment.cardLastFour,
        cardholderName: payment.cardholderName,
        locale: locale,
        prescriptionId: widget.prescriptionId,
        medicationId: widget.medicationId ?? widget.drugId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم الدفع بنجاح · تم إرسال الطلب: $_qty × ${widget.drugName} — بانتظار موافقة الصيدلية'
                : 'Mock payment authorized · Request sent: $_qty × ${widget.drugName} — awaiting pharmacy approval',
          ),
          backgroundColor: kPatientGoldDeep,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('prescription')
          ? (isArabic ? _rxBlockAr : _rxBlockEn)
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent.shade700),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _beginPurchase(String pharmacyId, {required bool isArabic}) async {
    await _purchase(pharmacyId, isArabic: isArabic);
  }

  Future<void> _openNearbySearch({required bool isArabic}) async {
    final pharmacyId = await showPatientNearbyPharmaciesSheet(
      context,
      drugId: widget.drugId,
      drugName: widget.drugName,
      searchOrigin: _searchOrigin(),
      excludePharmacyId: _excludeInternalPharmacyId(),
      radiusKm: 10,
    );
    if (pharmacyId != null && pharmacyId.isNotEmpty && mounted) {
      await _purchase(pharmacyId, isArabic: isArabic);
    }
  }

  Widget _nearbySearchButton({required bool isArabic, bool prominent = false}) {
    final label = isArabic ? 'ابحث في الصيدليات المجاورة' : 'Find in Nearby Pharmacies';
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : () => _openNearbySearch(isArabic: isArabic),
        style: OutlinedButton.styleFrom(
          foregroundColor: kPatientGold,
          side: BorderSide(
            color: kPatientGold.withValues(alpha: prominent ? 0.95 : 0.55),
            width: prominent ? 1.8 : 1.2,
          ),
          padding: EdgeInsets.symmetric(vertical: prominent ? 14 : 12, horizontal: 16),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: prominent ? kPatientGold.withValues(alpha: 0.08) : Colors.transparent,
        ),
        icon: Icon(
          prominent ? Icons.map_outlined : Icons.location_on_outlined,
          color: kPatientGold,
          size: 22,
        ),
        label: Text(
          label,
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.w700,
            fontSize: prominent ? 15 : 14,
            color: kPatientGoldLight,
          ),
        ),
      ),
    );
  }

  Widget _qtyStepper() {
    final maxQty = widget.maxQuantity;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
          icon: const Icon(Icons.remove_circle_outline, color: kPatientGold),
        ),
        Text('$_qty', style: patientTitleStyle(22)),
        IconButton(
          onPressed: maxQty != null && _qty >= maxQty
              ? null
              : () => setState(() => _qty++),
          icon: const Icon(Icons.add_circle_outline, color: kPatientGold),
        ),
        if (maxQty != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Max $maxQty',
              style: patientBodyStyle(color: Colors.white54, size: 12),
            ),
          ),
      ],
    );
  }

  Widget _pharmacyCard(
    Map<String, dynamic> ph, {
    required bool isArabic,
    required VoidCallback onBuy,
    bool enabled = true,
  }) {
    final name = patientLocaleSegment(ph['name']?.toString() ?? 'Pharmacy', isArabic: isArabic);
    final type = ph['pharmacyType']?.toString() ?? 'External';
    final dist = ph['distanceKm'];
    final stock = ph['stockQuantity'];
    final isInternal = type == 'Internal';
    final inStock = ph['inStock'] != false && (stock == null || (stock is num && stock > 0));
    final typeBadge = isInternal
        ? (isArabic ? 'عيادة' : 'Clinic')
        : (isArabic ? 'خارجي' : 'External');
    final stockLine = stock != null
        ? (isArabic ? 'المخزون: $stock' : 'Stock: $stock')
        : null;
    final distLine = dist != null
        ? (isArabic ? '$dist كم' : '$dist km away')
        : null;
    final addressRaw = ph['address']?.toString() ?? '';
    final addressLine = addressRaw.isNotEmpty ? patientLocaleSegment(addressRaw, isArabic: isArabic) : null;
    final outOfStockLine = isArabic
        ? 'غير متوفر في صيدلية العيادة'
        : 'Out of stock at clinic pharmacy';
    final requestBtn = _busy
        ? (isArabic ? 'جاري المعالجة…' : 'Processing…')
        : (isArabic ? 'اطلب من هذه الصيدلية' : 'Request from this pharmacy');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPatientFieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isInternal ? kPatientGold.withValues(alpha: 0.45) : Colors.white24,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInternal ? Icons.local_hospital : Icons.storefront_outlined,
                color: isInternal ? kPatientGold : Colors.orangeAccent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name, style: patientBodyStyle().copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isInternal ? kPatientGold : Colors.orangeAccent).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  typeBadge,
                  style: GoogleFonts.urbanist(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isInternal ? kPatientGold : Colors.orangeAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if ([stockLine, distLine, addressLine].any((s) => s != null && s.isNotEmpty))
            Text(
              [stockLine, distLine, addressLine].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
              style: patientBodyStyle(color: Colors.white54, size: 12),
            ),
          if (!inStock)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                outOfStockLine,
                style: patientBodyStyle(color: Colors.orangeAccent, size: 12),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy || !enabled || !inStock ? null : onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: kPatientGoldDeep,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(requestBtn),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _routingContent({required bool isArabic}) {
    if (_routing == null) return [];

    final externalList = _routing!['externalPharmacies'] as List<dynamic>? ?? [];
    final routingMsg = patientRoutingMessage(_routing!['message']?.toString(), isArabic: isArabic);
    final hasClinicPharmacy = _hasClinicPharmacy;
    final internalPharmacy = _internalPharmacyMap;
    final internalOutOfStock =
        hasClinicPharmacy && (_routing!['internalInStock'] != true || _internalStock <= 0);

    final widgets = <Widget>[];

    if (routingMsg.isNotEmpty) {
      widgets.add(Text(routingMsg, style: patientBodyStyle(color: Colors.white70, size: 13)));
      widgets.add(const SizedBox(height: 12));
    }

    if (hasClinicPharmacy && internalPharmacy != null) {
      widgets.addAll([
        Text(
          isArabic ? 'صيدلية العيادة' : 'Clinic Pharmacy',
          style: patientTitleStyle(15),
        ),
        const SizedBox(height: 8),
        _pharmacyCard(
          internalPharmacy,
          isArabic: isArabic,
          enabled: _routing!['internalInStock'] == true && _internalStock > 0,
          onBuy: () => _beginPurchase(
            internalPharmacy['pharmacyId']?.toString() ?? '',
            isArabic: isArabic,
          ),
        ),
        const SizedBox(height: 10),
        _nearbySearchButton(isArabic: isArabic, prominent: internalOutOfStock),
      ]);

      if (_routing!['showExternalFallback'] == true && externalList.isNotEmpty) {
        widgets.addAll([
          const SizedBox(height: 14),
          Text(
            isArabic ? 'صيدليات مقترحة قريبة:' : 'Suggested nearby (from routing):',
            style: patientBodyStyle(color: Colors.orangeAccent, size: 13),
          ),
          const SizedBox(height: 8),
          ...externalList.map((e) {
            final ph = Map<String, dynamic>.from(e as Map);
            return _pharmacyCard(
              ph,
              isArabic: isArabic,
              onBuy: () => _beginPurchase(ph['pharmacyId']?.toString() ?? '', isArabic: isArabic),
            );
          }),
        ]);
      }
      return widgets;
    }

    // No internal clinic pharmacy — nearby search only (full-width, prominent).
    widgets.add(_nearbySearchButton(isArabic: isArabic, prominent: true));

    if (externalList.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 14),
        Text(
          isArabic ? 'الصيدليات المجاورة' : 'Nearby Pharmacies',
          style: patientTitleStyle(15),
        ),
        const SizedBox(height: 8),
        ...externalList.map((e) {
          final ph = Map<String, dynamic>.from(e as Map);
          return _pharmacyCard(
            ph,
            isArabic: isArabic,
            onBuy: () => _beginPurchase(ph['pharmacyId']?.toString() ?? '', isArabic: isArabic),
          );
        }),
      ]);
    } else {
      widgets.addAll([
        const SizedBox(height: 12),
        Text(
          isArabic
              ? 'لا توجد صيدليات خارجية توفر هذا الدواء قريباً. استخدم البحث للعثور على صيدليات أخرى.'
              : 'No nearby pharmacies currently stock this medication. Use search to explore other options.',
          style: patientBodyStyle(color: Colors.white54, size: 13),
        ),
      ]);
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = patientIsArabic(context);
    final media = MediaQuery.of(context);
    final bottomPad = media.viewInsets.bottom + media.padding.bottom + 20;
    final maxSheetHeight = media.size.height * 0.92;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(widget.drugName, style: patientTitleStyle(18)),
            if (widget.requiresPrescription)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isArabic ? 'يتطلب وصفة طبية' : 'Prescription required',
                  style: patientBodyStyle(color: Colors.redAccent, size: 12),
                ),
              ),
            const SizedBox(height: 12),
            _qtyStepper(),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: kPatientGold)),
              )
            else if (_error != null)
              Text(_error!, style: patientBodyStyle(color: Colors.redAccent))
            else
              ..._routingContent(isArabic: isArabic),
          ],
        ),
      ),
    );
  }
}
