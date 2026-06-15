import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Shorthand alias matching common Flutter l10n conventions: `S.of(context).key`.
typedef S = AppLocalizations;

extension L10nBuildContext on BuildContext {
  /// Non-null localized strings for the active [MaterialApp] locale.
  S get l10n {
    final strings = S.of(this);
    assert(strings != null, 'AppLocalizations not found — wrap app in MaterialApp with localizationsDelegates');
    return strings!;
  }

  bool get isArabicLocale => Localizations.localeOf(this).languageCode == 'ar';

  TextDirection get localeDirection =>
      isArabicLocale ? TextDirection.rtl : TextDirection.ltr;
}
