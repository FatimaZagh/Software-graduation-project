import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _kGold = Color(0xFFD4AF37);

/// Duration units for [buildMedicationDurationString] / backend `parseDurationInDays`.
const List<String> kMedicationDurationUnits = ['Days', 'Weeks', 'Months'];

/// Validates the numeric duration value. Returns an error message or `null` if valid.
String? validateMedicationDurationValue(String? raw) {
  final q = raw?.trim() ?? '';
  if (q.isEmpty) return 'Enter a duration value';
  final n = int.tryParse(q);
  if (n == null || n < 1) return 'Enter a whole number (1 or greater)';
  return null;
}

/// Whether value + unit can be sent as `duration` on the prescription body.
bool isMedicationDurationReady(String valueRaw) =>
    validateMedicationDurationValue(valueRaw) == null;

/// Combines unit dropdown + value field into the API `duration` string.
///
/// Example A: unit `Weeks`, value `2` → `"2 weeks"`
/// Example B: unit `Days`, value `7` → `"7 days"`
/// Parses API `duration` (e.g. `"7 days"`) into value + unit for form fields.
({String value, String unit})? parseMedicationDurationString(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  final match = RegExp(r'^(\d+)\s*(day|days|week|weeks|month|months)$', caseSensitive: false).firstMatch(text);
  if (match == null) return null;
  final value = match.group(1)!;
  final unitToken = match.group(2)!.toLowerCase();
  final unit = unitToken.startsWith('week')
      ? 'Weeks'
      : unitToken.startsWith('month')
          ? 'Months'
          : 'Days';
  return (value: value, unit: unit);
}

String buildMedicationDurationString(String valueRaw, String unit) {
  if (!isMedicationDurationReady(valueRaw)) return '';
  final n = int.parse(valueRaw.trim());

  switch (unit) {
    case 'Weeks':
      return '$n weeks';
    case 'Months':
      return '$n months';
    case 'Days':
    default:
      return '$n days';
  }
}

/// Maps duration field to a dispense quantity ceiling for controlled Rx items.
int computePrescribedQuantityFromDuration(String valueRaw, String unit) {
  if (!isMedicationDurationReady(valueRaw)) return 1;
  final n = int.parse(valueRaw.trim());
  switch (unit) {
    case 'Weeks':
      return n * 7;
    case 'Months':
      return n * 30;
    case 'Days':
    default:
      return n;
  }
}

InputDecoration _goldDurationDec({String? label, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: GoogleFonts.urbanist(color: Colors.white38, fontSize: 13),
      labelStyle: GoogleFonts.urbanist(color: _kGold.withValues(alpha: 0.9)),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _kGold.withValues(alpha: 0.45))),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _kGold, width: 1.5)),
      errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 1.5)),
      filled: true,
      fillColor: const Color(0xFF1A1A18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );

/// Unit dropdown + numeric value (gold EMR theme). Unit appears first in the [Row].
class DoctorMedicationDurationField extends StatelessWidget {
  const DoctorMedicationDurationField({
    super.key,
    required this.quantityController,
    required this.unit,
    required this.onUnitChanged,
    this.sectionLabel = 'Duration',
    this.showSectionLabel = true,
    this.autovalidateMode,
    this.valueErrorText,
    this.enabled = true,
  });

  final TextEditingController quantityController;
  final String unit;
  final ValueChanged<String> onUnitChanged;
  final String sectionLabel;
  final bool showSectionLabel;
  final AutovalidateMode? autovalidateMode;
  final String? valueErrorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _MedicationDurationSplitRow(
      quantityController: quantityController,
      unit: unit,
      onUnitChanged: onUnitChanged,
      sectionLabel: sectionLabel,
      showSectionLabel: showSectionLabel,
      autovalidateMode: autovalidateMode,
      valueErrorText: valueErrorText,
      enabled: enabled,
      unitDecoration: _goldDurationDec(label: 'Duration unit'),
      valueDecoration: _goldDurationDec(label: 'Duration value', hint: 'e.g., 7 or 2'),
      valueStyle: const TextStyle(color: Colors.white),
      dropdownColor: const Color(0xFF1A1A18),
      dropdownStyle: const TextStyle(color: Colors.white),
      sectionLabelStyle: GoogleFonts.urbanist(
        color: _kGold.withValues(alpha: 0.85),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Unit dropdown + numeric value (Material / consultation theme).
class DoctorMedicationDurationFieldOutlined extends StatelessWidget {
  const DoctorMedicationDurationFieldOutlined({
    super.key,
    required this.quantityController,
    required this.unit,
    required this.onUnitChanged,
    this.sectionLabel = 'Duration',
    this.autovalidateMode,
    this.valueErrorText,
  });

  final TextEditingController quantityController;
  final String unit;
  final ValueChanged<String> onUnitChanged;
  final String sectionLabel;
  final AutovalidateMode? autovalidateMode;
  final String? valueErrorText;

  @override
  Widget build(BuildContext context) {
    final border = const OutlineInputBorder();
    return _MedicationDurationSplitRow(
      quantityController: quantityController,
      unit: unit,
      onUnitChanged: onUnitChanged,
      sectionLabel: sectionLabel,
      autovalidateMode: autovalidateMode,
      valueErrorText: valueErrorText,
      unitDecoration: InputDecoration(labelText: 'Duration unit', border: border),
      valueDecoration: InputDecoration(
        labelText: sectionLabel,
        hintText: 'e.g., 7 or 2',
        border: border,
      ),
    );
  }
}

class _MedicationDurationSplitRow extends StatelessWidget {
  const _MedicationDurationSplitRow({
    required this.quantityController,
    required this.unit,
    required this.onUnitChanged,
    required this.unitDecoration,
    required this.valueDecoration,
    this.sectionLabel = 'Duration',
    this.showSectionLabel = true,
    this.autovalidateMode,
    this.valueErrorText,
    this.valueStyle,
    this.dropdownColor,
    this.dropdownStyle,
    this.sectionLabelStyle,
    this.enabled = true,
  });

  final TextEditingController quantityController;
  final String unit;
  final ValueChanged<String> onUnitChanged;
  final InputDecoration unitDecoration;
  final InputDecoration valueDecoration;
  final String sectionLabel;
  final bool showSectionLabel;
  final AutovalidateMode? autovalidateMode;
  final String? valueErrorText;
  final TextStyle? valueStyle;
  final Color? dropdownColor;
  final TextStyle? dropdownStyle;
  final TextStyle? sectionLabelStyle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selectedUnit = kMedicationDurationUnits.contains(unit) ? unit : 'Days';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSectionLabel && sectionLabelStyle != null) ...[
          Text(sectionLabel, style: sectionLabelStyle),
          const SizedBox(height: 6),
        ],
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: selectedUnit,
                  isExpanded: true,
                  dropdownColor: dropdownColor,
                  style: dropdownStyle,
                  decoration: unitDecoration,
                  items: kMedicationDurationUnits
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: enabled
                      ? (v) {
                          if (v != null) onUnitChanged(v);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: quantityController,
                  enabled: enabled,
                  readOnly: !enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autovalidateMode: autovalidateMode,
                  style: valueStyle,
                  decoration: valueDecoration.copyWith(errorText: valueErrorText),
                  validator: validateMedicationDurationValue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
