// Rafeeq welcome / landing UI.
//
// - Data: GET {rafeeqApiBase}/api/organizations/active (organizations collection)
// - Routing: facility details `context.push('/facility/:orgId')`; legacy `/clinic/:id`, `/org/:id`
// - State is local StatefulWidget only (this app does not use Riverpod).

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'widgets/looping_asset_video_background.dart';

import 'api_config.dart';
import 'facility_registration_screen.dart';
import 'app_locale_scope.dart';
import 'widgets/responsive_layout.dart';
import 'login_screen.dart';
import 'features/auth/presentation/role_selection_screen.dart';
import 'l10n/l10n_extensions.dart';

const Color _welcomeGold = Color(0xFFD4AF37);
const Color _welcomeGlassFill = Color(0x42FFFFFF);

/// Premium landing hero palette (emerald / teal).
const Color _heroEmeraldAccent = Color(0xFF2DD4BF);
const Color _heroEmeraldFill = Color(0xFF0F766E);
const Color _heroTealOutline = Color(0xFF115E59);
const Color _heroOverlay = Color(0x99000000);

/// Contact section: continuous dark strip + form fields (matches facilities mood).
const Color _contactSectionGradientTop = Color(0xF0000000);
const Color _contactSectionGradientBottom = Color(0xFF030303);
const Color _contactFieldFill = Color(0xFF000000);
const Color _contactFieldBorder = Colors.white;

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _facilitiesSectionKey = GlobalKey();
  final GlobalKey _contactSectionKey = GlobalKey();

  List<Map<String, dynamic>> _facilities = [];
  bool _facilitiesLoading = true;
  String? _facilitiesError;
  Timer? _facilitiesPollTimer;

  @override
  void initState() {
    super.initState();

    _loadLandingFacilities();
    _facilitiesPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadLandingFacilities(quiet: true);
    });
  }

  Future<void> _loadLandingFacilities({bool quiet = false}) async {
    if (!quiet && mounted) {
      setState(() {
        _facilitiesLoading = true;
        _facilitiesError = null;
      });
    }

    try {
      final base = rafeeqApiBase;
      final res = await http
          .get(Uri.parse('$base/api/organizations/active'))
          .timeout(const Duration(seconds: 18));

      if (res.statusCode != 200) {
        throw Exception('Organizations (${res.statusCode}) ${res.body}');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) throw Exception('Invalid organizations payload');

      final merged = <Map<String, dynamic>>[];
      for (final row in decoded) {
        if (row is Map) {
          merged.add(_facilityItemFromOrganization(Map<String, dynamic>.from(row)));
        }
      }

      if (!mounted) return;
      setState(() {
        _facilities = merged;
        _facilitiesError = null;
        if (!quiet) _facilitiesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!quiet) {
          _facilitiesLoading = false;
          _facilitiesError = e.toString();
        }
      });
    }
  }

  Map<String, dynamic> _facilityItemFromOrganization(Map<String, dynamic> o) {
    final loc = o['location'];
    final locCity =
        loc is Map ? (loc['city'] ?? '').toString().trim() : '';
    final locAddr =
        loc is Map ? (loc['address'] ?? '').toString().trim() : '';
    final city = (o['city'] ?? locCity).toString().trim();
    final addr = (o['address'] ?? locAddr).toString().trim();
    final subtitle = [addr, city].where((s) => s.isNotEmpty).join(' • ');
    return <String, dynamic>{
      'kind': 'organization',
      '_id': o['_id'],
      'orgId': o['_id'],
      'name': (o['name'] ?? '').toString().trim(),
      'address': addr,
      'city': city,
      'subtitle': subtitle,
      'logoUrl': (o['logoUrl'] ?? '').toString(),
      'description': (o['description'] ?? '').toString().trim(),
    };
  }

  void _openLandingFacility(BuildContext context, Map<String, dynamic> item) {
    final orgId = (item['_id'] ?? item['orgId'])?.toString().trim() ?? '';
    if (orgId.isEmpty) return;
    context.push('/facility/$orgId');
  }

  Widget _facilityCard(
    BuildContext context,
    Map<String, dynamic> item, {
    required bool fixedHorizontalWidth,
  }) {
    return _LandingFacilityHoverCard(
      item: item,
      fixedHorizontalWidth: fixedHorizontalWidth,
      onOpen: () => _openLandingFacility(context, item),
    );
  }

  Widget _facilitiesSection(BuildContext context) {
    final l10n = context.l10n;
    final r = RafeeqResponsive.of(context);

    Widget body;
    if (_facilitiesLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: _welcomeGold),
          ),
        ),
      );
    } else if (_facilitiesError != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Text(
              l10n.landingCouldNotLoadFacilities,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
            Text(
              _facilitiesError!,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
            ),
            TextButton(
              onPressed: () => _loadLandingFacilities(),
              child: Text(l10n.retry, style: GoogleFonts.poppins(color: _welcomeGold)),
            ),
          ],
        ),
      );
    } else if (_facilities.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Text(
          l10n.landingNoFacilities,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 15,
            height: 1.45,
          ),
        ),
      );
    } else if (r.useFacilityListLayout) {
      body = ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(r.horizontalPadding, 8, r.horizontalPadding, 24),
        itemCount: _facilities.length,
        separatorBuilder: (_, __) => SizedBox(height: r.value(compact: 12.0, medium: 14.0, expanded: 14.0)),
        itemBuilder: (ctx, i) => _facilityCard(ctx, _facilities[i], fixedHorizontalWidth: false),
      );
    } else {
      final crossCount = r.facilityGridCrossAxisCount;
      final cardHeight = r.value(compact: 300.0, medium: 310.0, expanded: 328.0);
      body = GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(r.horizontalPadding, 8, r.horizontalPadding, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          crossAxisSpacing: r.value(compact: 12.0, medium: 14.0, expanded: 16.0),
          mainAxisSpacing: r.value(compact: 12.0, medium: 14.0, expanded: 16.0),
          mainAxisExtent: cardHeight,
        ),
        itemCount: _facilities.length,
        itemBuilder: (ctx, i) =>
            _facilityCard(ctx, _facilities[i], fixedHorizontalWidth: false),
      );
    }

    return Container(
      key: _facilitiesSectionKey,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.72),
            Colors.black.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(r.horizontalPadding, 28, r.horizontalPadding, 0),
            child: Text(
              l10n.landingOurFacilities,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                color: _welcomeGold,
                fontSize: r.scaleFont(r.value(compact: 22.0, medium: 24.0, expanded: 26.0)),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              l10n.landingTapFacilityHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: r.scaleFont(12),
                color: Colors.white54,
              ),
            ),
          ),
          body,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _facilitiesPollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      alignment: 0.05,
    );
  }

  InputDecoration _contactInputDecoration(String label) {
    const radius = 10.0;
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: _contactFieldBorder, width: 1.5),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: _contactFieldBorder, width: 2),
    );
    return InputDecoration(
      filled: true,
      fillColor: _contactFieldFill,
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.95),
      ),
      floatingLabelStyle: GoogleFonts.poppins(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      enabledBorder: baseBorder,
      focusedBorder: focusedBorder,
      border: baseBorder,
      disabledBorder: baseBorder,
      errorBorder: baseBorder,
      focusedErrorBorder: focusedBorder,
    );
  }

  Widget _contactFormColumn(BuildContext context) {
    final l10n = context.l10n;
    final fieldStyle = GoogleFonts.poppins(color: Colors.white, fontSize: 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          style: fieldStyle,
          cursorColor: Colors.white,
          decoration: _contactInputDecoration(l10n.landingContactName),
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 20),
        TextField(
          style: fieldStyle,
          cursorColor: Colors.white,
          decoration: _contactInputDecoration(l10n.landingContactEmail),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        TextField(
          style: fieldStyle,
          cursorColor: Colors.white,
          minLines: 4,
          maxLines: 6,
          decoration: _contactInputDecoration(l10n.landingContactMessage),
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: _contactFieldBorder, width: 1.5),
              ),
            ),
            child: Text(
              l10n.landingSendMessage,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contactSection(BuildContext context) {
    final l10n = context.l10n;
    final w = MediaQuery.sizeOf(context).width;
    final padH = w < 520 ? 20.0 : (w < 900 ? 32.0 : 80.0);
    final padV = w < 520 ? 40.0 : 56.0;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.landingContactUs,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: w < 520 ? 36 : 46,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.landingContactSubtitle,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: w < 520 ? 16 : 18,
            height: 1.45,
          ),
        ),
      ],
    );

    return Container(
      key: _contactSectionKey,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _contactSectionGradientTop,
            _contactSectionGradientBottom,
          ],
        ),
      ),
      padding: EdgeInsets.fromLTRB(padH, padV, padH, padV + 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 880;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: heading),
                const SizedBox(width: 40),
                Expanded(flex: 5, child: _contactFormColumn(context)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 32),
              _contactFormColumn(context),
            ],
          );
        },
      ),
    );
  }

  Widget _landingDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Material(
        color: const Color(0xCC0A1210),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: _heroEmeraldFill.withValues(alpha: 0.35),
              ),
              child: Text(
                context.l10n.landingMenu,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.login, color: Colors.white70),
              title: Text(context.l10n.landingLogin, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.white70),
              title: Text(context.l10n.landingSignUp, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroHeader(BuildContext context, RafeeqResponsive r) {
    final localeLabel = Localizations.localeOf(context).languageCode.toUpperCase();
    final pad = r.horizontalPadding.clamp(16.0, 48.0);
    final compact = r.isCompact;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const Spacer(),
          if (!compact)
            TextButton.icon(
              onPressed: () => MyAppLocaleController.toggleLocale(context),
              icon: const Icon(Icons.language_rounded, color: Colors.white, size: 20),
              label: Text(
                localeLabel,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            )
          else
            IconButton(
              tooltip: localeLabel,
              onPressed: () => MyAppLocaleController.toggleLocale(context),
              icon: Text(
                localeLabel,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          if (!compact)
            TextButton.icon(
              onPressed: () => _scrollToSection(_contactSectionKey),
              icon: const Icon(Icons.phone_outlined, color: Colors.white, size: 18),
              label: Text(
                context.l10n.landingContactUs,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
              ),
            )
          else
            IconButton(
              tooltip: context.l10n.landingContactUs,
              onPressed: () => _scrollToSection(_contactSectionKey),
              icon: const Icon(Icons.phone_outlined, color: Colors.white, size: 20),
            ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            onPressed: () => _scrollToSection(_facilitiesSectionKey),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: _heroTealOutline.withValues(alpha: 0.55),
              side: BorderSide(color: _heroEmeraldAccent.withValues(alpha: 0.65)),
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(
              compact ? 'Book' : 'Book Now',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rafeeqWordmark() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 30),
              Positioned(
                right: 4,
                bottom: 5,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Icon(Icons.add, color: _heroEmeraldFill, size: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'rafeeq',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _heroLeftContent(BuildContext context, RafeeqResponsive r) {
    final headlineSize = r.value(compact: 32.0, medium: 42.0, expanded: 52.0);
    final maxW = r.isCompact ? double.infinity : 640.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _rafeeqWordmark(),
          SizedBox(height: r.value(compact: 22.0, medium: 28.0, expanded: 34.0)),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: headlineSize,
                fontWeight: FontWeight.w700,
                height: 1.12,
                letterSpacing: -0.5,
              ),
              children: const [
                TextSpan(text: 'Exceptional care for a '),
                TextSpan(
                  text: 'better life',
                  style: TextStyle(color: _heroEmeraldAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Comprehensive medical services delivered by a dedicated team you can trust.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: r.value(compact: 14.0, medium: 16.0, expanded: 17.0),
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: r.value(compact: 22.0, medium: 28.0, expanded: 32.0)),
          FilledButton.icon(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const RoleSelectionScreen(),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: _heroEmeraldFill,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: r.value(compact: 20.0, medium: 24.0, expanded: 28.0),
                vertical: r.value(compact: 14.0, medium: 16.0, expanded: 18.0),
              ),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            icon: const Icon(Icons.calendar_month_outlined, size: 20),
            label: Text(
              'Book an Appointment',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const FacilityRegistrationScreen()),
              );
            },
            child: Text(
              context.l10n.landingRegisterFacility,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: _heroEmeraldAccent.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroFeatureBadge(RafeeqResponsive r) {
    Widget cell(IconData icon, String label) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _heroEmeraldAccent, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: r.isCompact ? 10.5 : 11.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      );
    }

    final cells = [
      cell(Icons.medical_services_outlined, 'Expert Doctors'),
      cell(Icons.schedule_rounded, 'Timely Care'),
      cell(Icons.monitor_heart_outlined, 'Compassionate Support'),
      cell(Icons.verified_user_outlined, 'Safe & Trusted Environment'),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _heroEmeraldAccent.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: _heroEmeraldAccent.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: r.isCompact
              ? Wrap(
                  alignment: WrapAlignment.center,
                  children: cells,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < cells.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          height: 56,
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      cells[i],
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _heroScrollIndicator() {
    return GestureDetector(
      onTap: () => _scrollToSection(_facilitiesSectionKey),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mouse_outlined, color: Colors.white.withValues(alpha: 0.65), size: 22),
          const SizedBox(height: 4),
          Text(
            'Scroll Down',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.72), size: 22),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, RafeeqResponsive r, double heroHeight) {
    final pad = r.horizontalPadding.clamp(16.0, 56.0);

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LoopingAssetVideoBackground(
            assetPath: kHospitalBackgroundVideoAsset,
            loading: const Center(child: CircularProgressIndicator(color: _heroEmeraldAccent)),
            errorBuilder: (context, initError, playerError) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0A1512),
                      _heroEmeraldFill.withValues(alpha: 0.45),
                    ],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.l10n.landingVideoLoadError(
                        '$initError${playerError != null ? "\n\n$playerError" : ""}',
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
              );
            },
          ),
          const ColoredBox(color: _heroOverlay),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heroHeader(context, r),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _heroLeftContent(context, r),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: pad,
            bottom: r.isCompact ? 72 : 88,
            left: r.isCompact ? pad : null,
            child: _heroFeatureBadge(r),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: r.isCompact ? 16 : 22,
            child: Center(child: _heroScrollIndicator()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = RafeeqResponsive.of(context);
    final viewportH = MediaQuery.sizeOf(context).height;
    final heroHeight = viewportH.clamp(520.0, 920.0);

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      drawer: _landingDrawer(),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildHeroSection(context, r, heroHeight),
            _facilitiesSection(context),
            _contactSection(context),
          ],
        ),
      ),
    );
  }
}

/// Facility card: image uses natural aspect + [BoxFit.contain] (no crop); frame hugs content; hover overlay unchanged.
class _LandingFacilityHoverCard extends StatefulWidget {
  const _LandingFacilityHoverCard({
    required this.item,
    required this.fixedHorizontalWidth,
    required this.onOpen,
  });

  final Map<String, dynamic> item;
  final bool fixedHorizontalWidth;
  final VoidCallback onOpen;

  @override
  State<_LandingFacilityHoverCard> createState() => _LandingFacilityHoverCardState();
}

class _LandingFacilityHoverCardState extends State<_LandingFacilityHoverCard> {
  bool _hover = false;
  /// Decoded width / height; null while resolving; 1.0 when no image or on error.
  double? _naturalAspect;
  String? _streamUrl;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  @override
  void didUpdateWidget(covariant _LandingFacilityHoverCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['logoUrl'] != widget.item['logoUrl']) {
      _detachImageStream();
      _streamUrl = null;
      _naturalAspect = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachImageStreamIfNeeded();
  }

  @override
  void dispose() {
    _detachImageStream();
    super.dispose();
  }

  void _detachImageStream() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageStream = null;
    _imageListener = null;
  }

  String? _logoUrlForStream() {
    final logo = (widget.item['logoUrl'] ?? '').toString().trim();
    if (logo.isEmpty) return null;
    try {
      final u = Uri.parse(logo);
      return u.hasScheme ? u.toString() : null;
    } catch (_) {
      return null;
    }
  }

  void _attachImageStreamIfNeeded() {
    final url = _logoUrlForStream();
    if (url == _streamUrl) return;

    _detachImageStream();
    _streamUrl = url;
    _naturalAspect = null;

    if (url == null) {
      setState(() => _naturalAspect = 1.0);
      return;
    }

    final provider = NetworkImage(url);
    _imageStream = provider.resolve(createLocalImageConfiguration(context));
    _imageListener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (!mounted || w <= 0 || h <= 0) return;
        setState(() => _naturalAspect = w / h);
      },
      onError: (Object _, StackTrace? stackTrace) {
        if (mounted) setState(() => _naturalAspect = 1.0);
      },
    );
    _imageStream!.addListener(_imageListener!);
  }

  @override
  Widget build(BuildContext context) {
    final r = RafeeqResponsive.of(context);
    final item = widget.item;
    final kind = (item['kind'] ?? 'clinic').toString();
    final name = (item['name'] ?? '').toString().trim();
    final orgName =
        kind == 'clinic' ? (item['organizationName'] ?? '').toString().trim() : '';
    final subtitleCandidate = (item['subtitle'] ?? '').toString().trim();
    final city = (item['city'] ?? '').toString().trim();
    final address = (item['address'] ?? '').toString().trim();
    final subtitle = subtitleCandidate.isNotEmpty
        ? subtitleCandidate
        : [address, city].where((s) => s.isNotEmpty).join(' • ');

    final description = (item['description'] ?? item['organizationDescription'] ?? '')
        .toString()
        .trim();
    final hasDescription = description.isNotEmpty;

    final logo = (item['logoUrl'] ?? '').toString().trim();
    Uri? logoUri;
    if (logo.isNotEmpty) {
      try {
        logoUri = Uri.parse(logo);
        if (!logoUri.hasScheme) logoUri = null;
      } catch (_) {
        logoUri = null;
      }
    }

    final hasLogo = logoUri != null;
    final ar = _naturalAspect;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = widget.fixedHorizontalWidth
            ? 268.0
            : constraints.maxWidth.clamp(120.0, 2000.0);
        final double imgH;
        if (!hasLogo) {
          imgH = (maxW * 0.42).clamp(72.0, 120.0);
        } else if (ar == null) {
          imgH = (maxW * 0.55).clamp(88.0, 140.0);
        } else {
          imgH = (maxW / ar).clamp(64.0, 200.0);
        }

        final Widget imageArea = !hasLogo
            ? ColoredBox(
                color: Colors.teal.withValues(alpha: 0.35),
                child: Center(
                  child: Icon(Icons.local_hospital_rounded, color: _welcomeGold.withValues(alpha: 0.9), size: 42),
                ),
              )
            : _naturalAspect == null
                ? ColoredBox(
                    color: Colors.black.withValues(alpha: 0.2),
                    child: const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _welcomeGold),
                      ),
                    ),
                  )
                : Image.network(
                    logoUri!.toString(),
                    width: maxW,
                    height: imgH,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: Colors.teal.withValues(alpha: 0.35),
                      child: Center(
                        child: Icon(Icons.local_hospital_rounded, color: _welcomeGold.withValues(alpha: 0.9), size: 42),
                      ),
                    ),
                  );

        final card = ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: maxW,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _welcomeGlassFill,
                    Colors.white.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(color: _welcomeGold.withValues(alpha: 0.95), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  alignment: Alignment.topCenter,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          child: SizedBox(
                            width: maxW,
                            height: imgH,
                            child: imageArea,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? context.l10n.landingFacilityFallback : name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.playfairDisplay(
                                  color: Colors.white,
                                  fontSize: r.scaleFont(r.value(compact: 16.0, medium: 17.0, expanded: 18.0)),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (orgName.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  orgName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: _welcomeGold.withValues(alpha: 0.95),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(Icons.location_on_outlined, color: _welcomeGold, size: 16),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      subtitle.isEmpty ? '—' : subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white.withValues(alpha: 0.92),
                                        fontSize: r.scaleFont(r.value(compact: 12.0, medium: 12.0, expanded: 12.5)),
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned.fill(
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        offset: _hover && hasDescription ? Offset.zero : const Offset(0, 0.05),
                        child: AnimatedOpacity(
                          opacity: _hover && hasDescription ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  alignment: Alignment.center,
                                  color: Colors.black.withValues(alpha: 0.55),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      description,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 13,
                                        height: 1.42,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        return MouseRegion(
          onEnter: (_) {
            if (hasDescription) setState(() => _hover = true);
          },
          onExit: (_) => setState(() => _hover = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onOpen,
              child: Align(
                alignment: Alignment.topCenter,
                child: card,
              ),
            ),
          ),
        );
      },
    );
  }
}
