import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'l10n/app_localizations.dart';

import 'app_locale_scope.dart';
import 'core/locale/locale_preferences.dart';
import 'facility_details_screen.dart';
import 'facility_entry_screens.dart';
import 'landing_screen.dart';
import 'login_screen.dart';

/// Platform-wide dark theme with browser-safe typography (Latin + Arabic).
const List<String> _kAppFontFallbacks = ['Noto Sans Arabic', 'sans-serif'];

ThemeData _rafeeqDarkTheme() {
  const fontFamily = 'Arial';
  const baseStyle = TextStyle(fontFamily: fontFamily, fontFamilyFallback: _kAppFontFallbacks);

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    fontFamily: fontFamily,
    fontFamilyFallback: _kAppFontFallbacks,
    textTheme: const TextTheme(
      displayLarge: baseStyle,
      displayMedium: baseStyle,
      displaySmall: baseStyle,
      headlineLarge: baseStyle,
      headlineMedium: baseStyle,
      headlineSmall: baseStyle,
      titleLarge: baseStyle,
      titleMedium: baseStyle,
      titleSmall: baseStyle,
      bodyLarge: baseStyle,
      bodyMedium: baseStyle,
      bodySmall: baseStyle,
      labelLarge: baseStyle,
      labelMedium: baseStyle,
      labelSmall: baseStyle,
    ),
    colorScheme: const ColorScheme.dark(
      surface: Color(0xFF121212),
      onSurface: Color(0xFFE8E8E8),
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initDesktopVideoBackends();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  runApp(const RafeeqRoot());
}

/// MediaKit is only required on Windows (video_player has no native Windows backend).
/// Calling [MediaKit.ensureInitialized] on Android/iOS crashes — libmpv is not bundled.
void _initDesktopVideoBackends() {
  if (defaultTargetPlatform != TargetPlatform.windows) return;
  try {
    MediaKit.ensureInitialized();
    VideoPlayerMediaKit.ensureInitialized(windows: true);
  } catch (error, stack) {
    debugPrint('MediaKit init failed (video backgrounds may not play on Windows): $error');
    debugPrint('$stack');
  }
}

/// Root app: locale + i18n + [go_router]. Landing UI lives in [LandingScreen].
class RafeeqRoot extends StatefulWidget {
  const RafeeqRoot({super.key});

  @override
  State<RafeeqRoot> createState() => _RafeeqRootState();
}

class _RafeeqRootState extends State<RafeeqRoot> {
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    try {
      final saved = await LocalePreferences.loadSavedLocale();
      if (!mounted) return;
      if (saved.languageCode != _locale.languageCode) {
        setState(() => _locale = saved);
      }
    } catch (error, stack) {
      debugPrint('LocalePreferences.loadSavedLocale failed: $error');
      debugPrint('$stack');
    }
  }

  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Page not found: ${state.uri}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE8E8E8)),
          ),
        ),
      ),
    ),
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/facility/:organizationId',
        builder: (context, state) {
          final id = state.pathParameters['organizationId'] ?? '';
          final extra = state.extra;
          final branch = extra is String ? extra : null;
          return FacilityDetailsScreen(
            organizationId: id,
            branchDisplayName: branch,
          );
        },
      ),
      GoRoute(
        path: '/clinic/:clinicId',
        builder: (context, state) {
          final id = state.pathParameters['clinicId'] ?? '';
          return ClinicFacilityEntryScreen(clinicId: id);
        },
      ),
      GoRoute(
        path: '/org/:orgId',
        builder: (context, state) {
          final id = state.pathParameters['orgId'] ?? '';
          return OrgFacilityEntryScreen(orgId: id);
        },
      ),
    ],
  );

  void _setLocale(Locale l) {
    setState(() => _locale = l);
    LocalePreferences.saveLocale(l);
  }

  @override
  Widget build(BuildContext context) {
    return MyAppLocaleController(
      locale: _locale,
      setLocale: _setLocale,
      child: MaterialApp.router(
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: _rafeeqDarkTheme(),
        darkTheme: _rafeeqDarkTheme(),
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
      ),
    );
  }
}
