import 'package:flutter/material.dart';

import 'pharmacist_theme.dart';

/// Fills the module panel with tight constraints (required under [Expanded] in shell).
class PharmacistModuleFill extends StatelessWidget {
  const PharmacistModuleFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: child);
  }
}

/// Header + scrollable/flex body; body receives bounded max height via [Expanded].
class PharmacistModuleSplit extends StatelessWidget {
  const PharmacistModuleSplit({
    super.key,
    required this.header,
    required this.body,
  });

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Full-panel vertical scroll for form-style modules.
class PharmacistModuleScroll extends StatelessWidget {
  const PharmacistModuleScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: child,
      ),
    );
  }
}

/// Centered loading indicator inside bounded module area.
class PharmacistModuleLoading extends StatelessWidget {
  const PharmacistModuleLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const PharmacistModuleFill(
      child: Center(
        child: CircularProgressIndicator(color: PharmacistTheme.gold),
      ),
    );
  }
}
