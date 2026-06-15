import 'package:flutter/material.dart';

import 'core/locale/locale_preferences.dart';

/// Inherited scope so any screen can read or toggle AR/EN via [RafeeqRoot].
class MyAppLocaleController extends InheritedWidget {
  const MyAppLocaleController({
    super.key,
    required this.locale,
    required this.setLocale,
    required super.child,
  });

  final Locale locale;
  final void Function(Locale locale) setLocale;

  static MyAppLocaleController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MyAppLocaleController>();
  }

  /// Toggle between English and Arabic, persist choice, rebuild app.
  static Future<void> toggleLocale(BuildContext context) async {
    final controller = of(context);
    if (controller == null) return;
    final next = controller.locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
    await LocalePreferences.saveLocale(next);
    controller.setLocale(next);
  }

  static Future<void> setLocaleCode(BuildContext context, String languageCode) async {
    final controller = of(context);
    if (controller == null) return;
    final next = Locale(languageCode);
    await LocalePreferences.saveLocale(next);
    controller.setLocale(next);
  }

  @override
  bool updateShouldNotify(MyAppLocaleController oldWidget) => locale != oldWidget.locale;
}
