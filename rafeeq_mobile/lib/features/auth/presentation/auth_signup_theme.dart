import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared palette for role selection and all registration forms.
abstract final class AuthSignupColors {
  static const gold = Color(0xFFD4AF37);
  static const goldMid = gold;
  static const goldLight = Color(0xFFFFE8A3);
  static const scaffoldBlack = Color(0xFF0B0B0C);
  static const fieldFill = Color(0xFF161A18);
  static const marble1 = fieldFill;
  static const glassCard = Color(0xE6101A18);
  static const glassTint = Color(0x38FFFFFF);
  static const infoPanelBg = Color(0xCC0A2F28);
  static const infoPanelBorder = Color(0xFF4DB6AC);
  static const infoIcon = Color(0xFFB2DFDB);

  static const gradientColors = [
    Color(0xFF0A0F0D),
    Color(0xFF1A1510),
    Color(0xFF0D1210),
  ];
}

abstract final class AuthSignupTheme {
  static TextStyle fieldTextStyle({double fontSize = 15}) {
    return GoogleFonts.urbanist(
      color: const Color(0xFFF5F5F0),
      fontSize: fontSize,
      height: 1.25,
    );
  }

  static TextStyle sectionTitleStyle({double fontSize = 20}) {
    return GoogleFonts.urbanist(
      color: AuthSignupColors.gold,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );
  }

  static TextStyle screenTitleStyle({double fontSize = 22}) {
    return GoogleFonts.urbanist(
      color: AuthSignupColors.gold,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
    );
  }

  static InputDecoration inputDecoration(
    String label, {
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    const gold = AuthSignupColors.gold;
    final enabled = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: gold.withValues(alpha: 0.55), width: 1.35),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.urbanist(
        color: gold.withValues(alpha: 0.92),
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: GoogleFonts.urbanist(
        color: AuthSignupColors.goldLight,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: AuthSignupColors.goldLight, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AuthSignupColors.fieldFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: enabled,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AuthSignupColors.gold, width: 1.65),
      ),
      errorBorder: enabled,
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade300, width: 1.35),
      ),
      border: enabled,
    );
  }

  static ButtonStyle primaryButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: AuthSignupColors.gold,
      foregroundColor: Colors.black,
      disabledBackgroundColor: AuthSignupColors.gold.withValues(alpha: 0.45),
      minimumSize: const Size(double.infinity, 52),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16),
    );
  }

  static ButtonStyle outlineButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AuthSignupColors.goldLight,
      side: const BorderSide(color: AuthSignupColors.gold, width: 1.4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
    );
  }

  static BoxDecoration gradientBackgroundDecoration() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AuthSignupColors.gradientColors,
      ),
    );
  }

  static PreferredSizeWidget authAppBar({
    required BuildContext context,
    required String title,
    bool automaticallyImplyLeading = true,
    Widget? leading,
  }) {
    return AppBar(
      backgroundColor: AuthSignupColors.scaffoldBlack.withValues(alpha: 0.55),
      elevation: 0,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      foregroundColor: AuthSignupColors.goldLight,
      iconTheme: const IconThemeData(color: AuthSignupColors.goldLight),
      title: Text(title, style: screenTitleStyle(fontSize: 20)),
    );
  }

  static Widget darkGradientScaffold({
    required BuildContext context,
    required String appBarTitle,
    required Widget body,
    bool automaticallyImplyLeading = true,
    Widget? leading,
    List<Widget>? stackOverlay,
  }) {
    return Scaffold(
      backgroundColor: AuthSignupColors.scaffoldBlack,
      extendBodyBehindAppBar: true,
      appBar: authAppBar(
        context: context,
        title: appBarTitle,
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading: leading,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: gradientBackgroundDecoration()),
          SafeArea(child: body),
          ...?stackOverlay,
        ],
      ),
    );
  }

  static Widget primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: primaryButtonStyle(),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : Text(label, style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }

  static Color dropdownSurfaceColor() => const Color(0xFF1A2220);
}
