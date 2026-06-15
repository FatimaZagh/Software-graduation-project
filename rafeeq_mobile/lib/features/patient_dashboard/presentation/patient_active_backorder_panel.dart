import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../tenant_state.dart';
import '../../auth/data/pharmacy_cities.dart';
import '../data/patient_backorder_item.dart';
import '../data/patient_portal_api.dart';
import 'patient_locale_text.dart';
import 'patient_nearby_pharmacies_sheet.dart';
import 'patient_theme.dart';

/// Single active backorder card with nearby pharmacy shortcut.
class PatientActiveBackorderPanel extends StatelessWidget {
  const PatientActiveBackorderPanel({
    super.key,
    required this.patientUserId,
    required this.item,
    this.onDismiss,
    this.showSectionHeader = false,
  });

  final String patientUserId;
  final PatientBackorderItem item;
  final VoidCallback? onDismiss;
  final bool showSectionHeader;

  Future<void> _openNearby(BuildContext context) async {
    if (item.drugId.isEmpty || item.backorderQty <= 0) return;

    LatLng origin = kPharmacyCities.first.center;
    try {
      final clinicId = TenantState.instance.preferredClinicId.trim();
      final routing = await PatientPortalApi.getPharmacyRouting(
        patientUserId,
        drugId: item.drugId,
        clinicId: clinicId.isEmpty ? null : clinicId,
        lat: origin.latitude,
        lng: origin.longitude,
      );
      final internal = routing['internalPharmacy'];
      if (internal is Map) {
        final lat = internal['latitude'];
        final lng = internal['longitude'];
        if (lat != null && lng != null) {
          origin = LatLng((lat as num).toDouble(), (lng as num).toDouble());
        }
      }
    } catch (_) {}

    if (!context.mounted) return;
    await showPatientNearbyPharmaciesSheet(
      context,
      drugId: item.drugId,
      drugName: item.medicationName,
      searchOrigin: origin,
      excludePharmacyId: item.pharmacyId,
      remainingQty: item.backorderQty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = patientIsArabic(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPatientGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPatientGold.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: kPatientGold.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSectionHeader)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isArabic ? '📦 طلبات مؤجلة نشطة' : '📦 Active Backorders',
                      style: patientTitleStyle(15),
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: isArabic ? 'إخفاء' : 'Dismiss',
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.medicationName,
                  style: patientBodyStyle().copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              if (!showSectionHeader && onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (item.fulfilledQty > 0)
            Text(
              isArabic
                  ? 'تم توفير: ${item.fulfilledQty} علب'
                  : 'Fulfilled: ${item.fulfilledQty} units',
              style: patientBodyStyle(color: const Color(0xFF4CAF50), size: 13),
            ),
          if (item.backorderQty > 0)
            Text(
              isArabic
                  ? 'قيد الانتظار: ${item.backorderQty} علب معلقة'
                  : 'Backorder: ${item.backorderQty} units pending',
              style: patientBodyStyle(color: kPatientGoldLight, size: 13),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: item.backorderQty > 0 ? () => _openNearby(context) : null,
              icon: const Icon(Icons.map_outlined, color: kPatientGold, size: 20),
              label: Text(
                isArabic
                    ? 'ابحث عن المتبقي في الصيدليات المجاورة'
                    : 'Find Remaining in Nearby Pharmacies',
                style: GoogleFonts.urbanist(
                  color: kPatientGoldLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: kPatientGold.withValues(alpha: 0.75), width: 1.4),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: kPatientGold.withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated stack of active backorder banners for the pharmacy dashboard.
class PatientActiveBackordersSection extends StatelessWidget {
  const PatientActiveBackordersSection({
    super.key,
    required this.patientUserId,
    required this.items,
    this.onDismissAll,
    this.onDismissItem,
  });

  final String patientUserId;
  final List<PatientBackorderItem> items;
  final VoidCallback? onDismissAll;
  final void Function(String id)? onDismissItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isArabic = patientIsArabic(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -0.06), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey('backorders-${items.map((e) => e.id).join(',')}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isArabic ? '📦 طلبات مؤجلة نشطة' : '📦 Active Backorders',
                  style: patientTitleStyle(16),
                ),
              ),
              if (onDismissAll != null)
                IconButton(
                  onPressed: onDismissAll,
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  tooltip: isArabic ? 'إخفاء الكل' : 'Dismiss all',
                ),
            ],
          ),
          const SizedBox(height: 4),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return TweenAnimationBuilder<double>(
              key: ValueKey(item.id),
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 320 + (index * 90)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: PatientActiveBackorderPanel(
                patientUserId: patientUserId,
                item: item,
                onDismiss: onDismissItem != null ? () => onDismissItem!(item.id) : null,
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
