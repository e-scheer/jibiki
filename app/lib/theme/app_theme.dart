import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// jibiki's design system, warm and content-first. A crisp near-white base
/// (warm near-black in dark), near-black type set in Inter, and a single
/// vermilion (朱) action colour: the red-orange of torii gates and hanko seals.
/// Hairline separators, generous air, and a warm ember gradient reserved for
/// hero moments and rings. Flat by default; the content is the loudest thing.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Inter';

  // Signature action colour: vermilion (朱). `vermilion` is the name it goes by.
  static const Color brand = Color(0xFFD4402A);
  static const Color vermilion = brand;
  static const Color ink = Color(0xFF141210);
  static const Color paper = Color(0xFFFFFFFF);

  // A warm ember gradient, hero CTAs, story-style rings, progress flourish.
  // Both stops are dark enough that white body text clears 4.5:1 anywhere on it.
  static const List<Color> gradient = [
    Color(0xFFD4402A),
    Color(0xFFA82C3A),
  ];
  static const LinearGradient brandGradient = LinearGradient(
    colors: gradient,
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final jc = b == Brightness.light ? JibikiColors.light : JibikiColors.dark;
    final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: b).copyWith(
      primary: jc.brand,
      surface: jc.surface,
      onSurface: jc.ink,
      surfaceContainerHighest: jc.surfaceAlt,
      outlineVariant: jc.hairline,
      error: jc.ratingAgain,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, fontFamily: fontFamily);
    return base.copyWith(
      scaffoldBackgroundColor: jc.canvas,
      extensions: [jc],
      splashFactory: NoSplash.splashFactory, // taps are crisp, not rippled
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _ReduceAwarePageTransitions(ZoomPageTransitionsBuilder()),
        TargetPlatform.iOS: _ReduceAwarePageTransitions(CupertinoPageTransitionsBuilder()),
      }),
      textTheme: _text(base.textTheme, jc),
      appBarTheme: AppBarTheme(
        backgroundColor: jc.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: jc.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w800, color: jc.ink, letterSpacing: -0.4),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: jc.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: jc.hairline, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: jc.surfaceAlt,
        side: BorderSide.none,
        labelStyle: TextStyle(color: jc.body, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: fontFamily),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: jc.surfaceAlt,
        hintStyle: TextStyle(color: jc.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(jc.muted),
        errorBorder: _inputBorder(jc.ratingAgain),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: jc.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: jc.brand.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white,
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: jc.ink,
          side: BorderSide(color: jc.hairline),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: jc.brand,
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: jc.canvas,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 64,
        // The current tab labels itself (wayfinding) and wears the vermilion; the
        // rest stay quiet icons, so the bar reads without shouting.
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: s.contains(WidgetState.selected) ? jc.brand : jc.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 25, color: s.contains(WidgetState.selected) ? jc.brand : jc.muted),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: jc.ink,
        contentTextStyle: TextStyle(color: jc.canvas, fontWeight: FontWeight.w600, fontFamily: fontFamily),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: jc.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: jc.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color c, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: c, width: width),
      );

  static TextTheme _text(TextTheme base, JibikiColors jc) {
    TextStyle s(double size, FontWeight w, {double h = 1.25, double ls = -0.2, Color? c}) => TextStyle(
        fontFamily: fontFamily, fontSize: size, fontWeight: w, height: h, letterSpacing: ls, color: c ?? jc.ink);
    return base.copyWith(
      displaySmall: s(32, FontWeight.w900, ls: -0.8),
      headlineMedium: s(26, FontWeight.w800, ls: -0.6),
      headlineSmall: s(21, FontWeight.w800, ls: -0.4),
      titleLarge: s(18, FontWeight.w700, ls: -0.3),
      titleMedium: s(15.5, FontWeight.w700, ls: -0.2),
      bodyLarge: s(15.5, FontWeight.w400, h: 1.45, ls: -0.1, c: jc.body),
      bodyMedium: s(14.5, FontWeight.w400, h: 1.45, ls: -0.1, c: jc.body),
      labelLarge: s(14, FontWeight.w600, ls: 0),
      labelMedium: s(12.5, FontWeight.w600, ls: 0, c: jc.muted),
    );
  }
}

/// Wraps a platform page transition so it collapses to an instant cut when the OS
/// "reduce motion" setting is on, and plays the idiomatic transition otherwise.
class _ReduceAwarePageTransitions extends PageTransitionsBuilder {
  const _ReduceAwarePageTransitions(this._inner);
  final PageTransitionsBuilder _inner;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return _inner.buildTransitions(route, context, animation, secondaryAnimation, child);
  }
}

/// Semantic colours beyond the Material ColorScheme, read via `context.jc`.
@immutable
class JibikiColors extends ThemeExtension<JibikiColors> {
  const JibikiColors({
    required this.brand,
    required this.brandPressed,
    required this.brandSoft,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.body,
    required this.muted,
    required this.hairline,
    required this.ratingAgain,
    required this.ratingHard,
    required this.ratingGood,
    required this.ratingEasy,
    required this.success,
    required this.warn,
  });

  final Color brand, brandPressed, brandSoft;
  final Color canvas, surface, surfaceAlt, ink, body, muted, hairline;
  final Color ratingAgain, ratingHard, ratingGood, ratingEasy;
  final Color success, warn;

  /// The warm ember gradient (hero CTAs, story rings, progress).
  List<Color> get instaGradient => AppTheme.gradient;
  LinearGradient get instaLinear => AppTheme.brandGradient;

  // Light, warmth is carried by the accent, never by the body background, so the
  // base stays a true white (surfaceAlt/hairline lean a hair toward the vermilion
  // hue for cohesion, not toward cream). Every colour used as text clears WCAG AA.
  static const light = JibikiColors(
    brand: Color(0xFFD4402A),        // vermilion 朱, white text 4.6:1
    brandPressed: Color(0xFFB4301F), // darker vermilion (pressed / text-on-soft)
    brandSoft: Color(0xFFFBEAE4),    // warm wash behind brand text + icons
    canvas: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4F1EF),   // barely-warm neutral, not cream
    ink: Color(0xFF141210),          // warm near-black
    body: Color(0xFF29251F),         // warm dark grey, ~13:1 on white
    muted: Color(0xFF6E6A66),        // 5.4:1 on white, 4.9:1 on surfaceAlt
    hairline: Color(0xFFE3DEDA),
    ratingAgain: Color(0xFFC62828),  // deep red, 5.6:1 as text
    ratingHard: Color(0xFFB45309),   // burnt amber, 5.0:1 as text
    ratingGood: Color(0xFF15803D),   // deep green, 5.0:1 as text
    ratingEasy: Color(0xFF5B51D8),   // indigo, 5.8:1 as text
    success: Color(0xFF15803D),
    warn: Color(0xFFB45309),
  );

  // Dark, the vermilion brightens so it stays legible on warm near-black; rating
  // hues lift into their brighter register. Depth comes from surface lightness.
  static const dark = JibikiColors(
    brand: Color(0xFFF0562F),        // brighter vermilion for dark surfaces
    brandPressed: Color(0xFFF47A5A),
    brandSoft: Color(0xFF3A1712),    // deep warm wash
    canvas: Color(0xFF0C0A09),       // warm near-black
    surface: Color(0xFF171412),
    surfaceAlt: Color(0xFF221E1B),
    ink: Color(0xFFFBFAF9),          // warm white
    body: Color(0xFFE7E2DE),
    muted: Color(0xFFA8A29C),        // warm muted, ~7:1 on canvas
    hairline: Color(0xFF352F2B),
    ratingAgain: Color(0xFFFF6B6B),
    ratingHard: Color(0xFFF5A623),
    ratingGood: Color(0xFF3DD07E),
    ratingEasy: Color(0xFF8B82F5),
    success: Color(0xFF3DD07E),
    warn: Color(0xFFF5A623),
  );

  @override
  JibikiColors copyWith() => this;

  @override
  JibikiColors lerp(ThemeExtension<JibikiColors>? other, double t) {
    if (other is! JibikiColors) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return JibikiColors(
      brand: m(brand, other.brand),
      brandPressed: m(brandPressed, other.brandPressed),
      brandSoft: m(brandSoft, other.brandSoft),
      canvas: m(canvas, other.canvas),
      surface: m(surface, other.surface),
      surfaceAlt: m(surfaceAlt, other.surfaceAlt),
      ink: m(ink, other.ink),
      body: m(body, other.body),
      muted: m(muted, other.muted),
      hairline: m(hairline, other.hairline),
      ratingAgain: m(ratingAgain, other.ratingAgain),
      ratingHard: m(ratingHard, other.ratingHard),
      ratingGood: m(ratingGood, other.ratingGood),
      ratingEasy: m(ratingEasy, other.ratingEasy),
      success: m(success, other.success),
      warn: m(warn, other.warn),
    );
  }
}

/// The Japanese faces used on study prompts. The same glyph shown in different
/// hands (gothic · mincho · brush) trains the eye to recognise its variants, the
/// way it appears across print and handwriting.
class JpFonts {
  JpFonts._();
  static const List<String> study = ['NotoSansJP', 'NotoSerifJP', 'YujiSyuku'];

  /// A face chosen from [seed] - pass a card's repetition count so the learner
  /// meets the same character in a different hand each time it comes back around.
  static String variant(int seed) => study[seed.abs() % study.length];
}

class Insets {
  Insets._();
  static const double xs = 4, sm = 8, md = 12, base = 16, lg = 20, xl = 24, xxl = 32, huge = 40;
}

class Radii {
  Radii._();
  static const double sm = 10, md = 14, lg = 18, xl = 26, pill = 999;
}

class Motion {
  Motion._();
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 210);
  static const Duration slow = Duration(milliseconds: 340);
  static const Curve out = Curves.easeOutCubic;
  static const Curve outStrong = Curves.easeOutQuint;

  /// True when the OS "reduce motion" accessibility setting is OFF, i.e. motion is
  /// allowed. Gate every non-essential animation on this and fall back to an
  /// instant / crossfade alternative when it returns false.
  static bool enabled(BuildContext c) => !MediaQuery.disableAnimationsOf(c);

  /// A duration that collapses to zero when reduce-motion is on. Hand this to
  /// implicit animations (AnimatedFoo) so they snap instead of animate.
  static Duration timed(BuildContext c, Duration d) => enabled(c) ? d : Duration.zero;
}

class Shadows {
  Shadows._();
  static List<BoxShadow> soft(BuildContext c) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: Theme.of(c).brightness == Brightness.light ? 0.05 : 0.4),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
  static List<BoxShadow> lifted(BuildContext c) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: Theme.of(c).brightness == Brightness.light ? 0.10 : 0.55),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
      ];
}

class Haptics {
  Haptics._();
  static void tick() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void success() => HapticFeedback.mediumImpact();
}

extension JibikiThemeX on BuildContext {
  JibikiColors get jc => Theme.of(this).extension<JibikiColors>() ?? JibikiColors.light;
  TextTheme get text => Theme.of(this).textTheme;
}
