import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../landing_screen.dart';
import 'responsive_layout.dart';

/// Signature golden-yellow used across Rafeeq auth flows.
const Color kRafeeqBackGold = Color(0xFFD4AF37);
const Color kRafeeqBackGoldLight = Color(0xFFFFE8A3);

/// Navigates to the public landing page — reliable after auth logout clears the stack.
void rafeeqNavigateBackToHome(BuildContext context) {
  try {
    GoRouter.maybeOf(context)?.go('/');
  } catch (_) {}

  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LandingScreen()),
    (_) => false,
  );
}

/// Golden glass back control — 48×48 minimum touch target, RTL-aware arrow.
class RafeeqBackHomeButton extends StatelessWidget {
  const RafeeqBackHomeButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Back to home',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed ?? () => rafeeqNavigateBackToHome(context),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.38),
                  border: Border.all(color: kRafeeqBackGold.withValues(alpha: 0.85), width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: kRafeeqBackGold.withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Icon(
                      isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                      color: kRafeeqBackGoldLight,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// For [Stack] layouts (login, video backgrounds): must be the **last** Stack child.
class RafeeqBackHomeOverlay extends StatelessWidget {
  const RafeeqBackHomeOverlay({super.key, this.onPressed, this.topOffset = 8});

  final VoidCallback? onPressed;
  final double topOffset;

  static const double _desktopInset = 32;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > RafeeqBreakpoints.tablet;

    if (isDesktop) {
      return PositionedDirectional(
        top: _desktopInset,
        start: _desktopInset,
        child: RafeeqBackHomeButton(onPressed: onPressed),
      );
    }

    return PositionedDirectional(
      top: 0,
      start: 0,
      end: 0,
      child: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              top: topOffset,
              start: RafeeqResponsive.of(context).backButtonStartInset,
            ),
            child: RafeeqBackHomeButton(onPressed: onPressed),
          ),
        ),
      ),
    );
  }
}

/// AppBar [leading] slot with consistent golden back control.
Widget rafeeqBackHomeAppBarLeading(BuildContext context, {VoidCallback? onPressed}) {
  return Padding(
    padding: const EdgeInsetsDirectional.only(start: 4),
    child: RafeeqBackHomeButton(onPressed: onPressed),
  );
}
