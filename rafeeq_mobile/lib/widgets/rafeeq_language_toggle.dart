import 'package:flutter/material.dart';

import '../app_locale_scope.dart';
import '../l10n/l10n_extensions.dart';

/// AppBar language toggle — switches EN ↔ AR via global [MyAppLocaleController].
class RafeeqLanguageToggle extends StatelessWidget {
  const RafeeqLanguageToggle({
    super.key,
    this.iconColor,
    this.icon = Icons.translate,
  });

  final Color? iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: l10n.language,
      icon: Icon(icon, color: iconColor),
      onPressed: () => MyAppLocaleController.toggleLocale(context),
    );
  }
}
