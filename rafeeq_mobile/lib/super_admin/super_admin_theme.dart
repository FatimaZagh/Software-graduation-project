import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kSuperAdminBlue = Color(0xFF283593);
const Color kSuperAdminBlueDark = Color(0xFF1A237E);
const Color kSuperAdminAccent = Color(0xFF3949AB);
const Color kSuperAdminSurface = Color(0xFFF5F7FB);
const Color kSuperAdminCard = Colors.white;
const Color kSuperAdminSuccess = Color(0xFF2E7D32);

/// Premium dark workspace — matches patient-portal EHR / payment views.
const Color kSuperAdminPremiumBg = Color(0xFF121212);
const Color kSuperAdminPremiumCard = Color(0xFF1E1E1E);
const Color kSuperAdminGold = Color(0xFFD4AF37);

TextStyle superAdminTitle([double size = 18]) =>
    GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size);

TextStyle superAdminBody({Color? color, double size = 14}) =>
    GoogleFonts.urbanist(color: color ?? const Color(0xFF263238), fontSize: size);

TextStyle superAdminPremiumHeading([double size = 15]) =>
    GoogleFonts.urbanist(color: kSuperAdminGold, fontWeight: FontWeight.w700, fontSize: size);

TextStyle superAdminPremiumLabel({double size = 12.5}) =>
    GoogleFonts.urbanist(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: size);

TextStyle superAdminPremiumValue({double size = 14}) =>
    GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size);

TextStyle superAdminPremiumMuted({double size = 13}) =>
    GoogleFonts.urbanist(color: Colors.white54, fontSize: size);

BoxDecoration superAdminPremiumCardDecoration({double borderWidth = 1.2}) => BoxDecoration(
      color: kSuperAdminPremiumCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kSuperAdminGold.withValues(alpha: 0.85), width: borderWidth),
    );
