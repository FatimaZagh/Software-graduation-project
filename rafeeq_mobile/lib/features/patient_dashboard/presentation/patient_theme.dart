import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kPatientWorkspaceBlack = Color(0xFF0A0F0D);
const Color kPatientFieldFill = Color(0xFF161A18);
const Color kPatientGold = Color(0xFFD4AF37);
const Color kPatientGoldLight = Color(0xFFFFE8A3);
const Color kPatientGoldDeep = Color(0xFFB8860B);
const Color kPatientSheetBg = Color(0xFF141A17);

InputDecoration patientInputDec(String label, {String? hint}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: kPatientGold.withValues(alpha: 0.65)),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(color: kPatientGold.withValues(alpha: 0.85)),
    hintStyle: TextStyle(color: Colors.white38),
    filled: true,
    fillColor: kPatientFieldFill,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: const BorderSide(color: kPatientGold, width: 1.4)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

TextStyle patientTitleStyle([double size = 18]) =>
    GoogleFonts.urbanist(color: kPatientGold, fontWeight: FontWeight.w700, fontSize: size);

TextStyle patientBodyStyle({Color? color, double size = 15}) =>
    GoogleFonts.urbanist(color: color ?? Colors.white, fontSize: size);

ThemeData patientPickerTheme(BuildContext context) {
  return ThemeData.dark().copyWith(
    colorScheme: const ColorScheme.dark(
      primary: kPatientGold,
      onPrimary: kPatientWorkspaceBlack,
      surface: kPatientSheetBg,
      onSurface: Colors.white,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: kPatientSheetBg),
  );
}
