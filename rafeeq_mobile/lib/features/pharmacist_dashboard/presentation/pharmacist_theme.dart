import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Unified dark enterprise palette for pharmacist workspace.
class PharmacistTheme {
  static const Color bg = Color(0xFF121212);
  static const Color card = Color(0xFF1E1E1E);
  static const Color gold = Color(0xFFD4AF37);
  static const Color greyText = Color(0xFFB3B3B3);
  static const Color green = Color(0xFF66BB6A);
  static const Color orange = Color(0xFFFFA726);
  static const Color red = Color(0xFFEF5350);

  static const double sidebarWidth = 260;

  static InputDecoration inputDec(String label, {String? hint, Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.urbanist(color: greyText, fontSize: 13),
      hintStyle: GoogleFonts.urbanist(color: greyText.withValues(alpha: 0.6), fontSize: 13),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF161616),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: gold, width: 1.4),
      ),
    );
  }

  static TextStyle titleStyle([double size = 22]) => GoogleFonts.urbanist(
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.w800,
      );

  static TextStyle bodyStyle([Color? color]) => GoogleFonts.urbanist(
        color: color ?? greyText,
        fontSize: 14,
        height: 1.4,
      );

  static BoxDecoration cardDec({Color? borderColor}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (borderColor ?? gold).withValues(alpha: 0.25)),
      );
}
