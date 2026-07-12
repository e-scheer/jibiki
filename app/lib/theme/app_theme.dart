import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme_controller.dart';

/// jibiki's Neo-pop design system: crisp surfaces, hard outlines, offset shadows
/// and vivid semantic colours. Content remains the loudest thing.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'SpaceGrotesk';
  static const List<String> fontFamilyFallback = [
    'ZenKakuGothicNew',
    'NotoSansJP',
  ];

  // Default signature action colour: Klein blue.
  static const Color brand = Color(0xFF2B36E3);
  static const Color vermilion = brand;
  static const Color ink = Color(0xFF141210);
  static const Color paper = Color(0xFFFFFFFF);

  // Vivid hero gradient used only for high-energy progress moments.
  static const List<Color> gradient = [Color(0xFF2B36E3), Color(0xFFFF57A8)];
  static const LinearGradient brandGradient = LinearGradient(
    colors: gradient,
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  static ThemeData light([ThemePalette palette = ThemePalette.neopop]) =>
      _build(Brightness.light, palette);
  static ThemeData dark([ThemePalette palette = ThemePalette.neopop]) =>
      _build(Brightness.dark, palette);

  static ThemeData _build(Brightness b, ThemePalette palette) {
    final jc = JibikiColors.forPalette(palette, b);
    final scheme =
        ColorScheme.fromSeed(seedColor: brand, brightness: b).copyWith(
      primary: jc.brand,
      surface: jc.surface,
      onSurface: jc.ink,
      surfaceContainerHighest: jc.surfaceAlt,
      outlineVariant: jc.hairline,
      error: jc.ratingAgain,
    );

    final base = ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        brightness: b,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback);
    return base.copyWith(
      scaffoldBackgroundColor: jc.canvas,
      extensions: [jc],
      splashFactory: NoSplash.splashFactory, // taps are crisp, not rippled
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android:
            _ReduceAwarePageTransitions(_NeoPopTransition()),
        TargetPlatform.iOS: _ReduceAwarePageTransitions(_NeoPopTransition()),
        TargetPlatform.macOS: _ReduceAwarePageTransitions(_NeoPopTransition()),
        TargetPlatform.windows:
            _ReduceAwarePageTransitions(_NeoPopTransition()),
        TargetPlatform.linux: _ReduceAwarePageTransitions(_NeoPopTransition()),
      }),
      textTheme: _text(base.textTheme, jc),
      appBarTheme: AppBarTheme(
        backgroundColor: jc.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: jc.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 68,
        shape: Border(
          bottom: BorderSide(color: jc.ink, width: 3),
        ),
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: jc.ink,
            letterSpacing: -0.4),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: jc.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: jc.ink, width: 2.5),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme:
          DividerThemeData(color: jc.hairline, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: jc.ink,
        textColor: jc.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: jc.surfaceAlt,
        side: BorderSide(color: jc.ink, width: 2),
        labelStyle: TextStyle(
            color: jc.body,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            fontFamily: fontFamily),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? jc.acid : jc.surface,
          ),
          foregroundColor: WidgetStatePropertyAll(jc.ink),
          side: WidgetStatePropertyAll(BorderSide(color: jc.ink, width: 2.5)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: jc.surface,
        hintStyle: TextStyle(color: jc.muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _inputBorder(jc.ink, width: 2.5),
        enabledBorder: _inputBorder(jc.ink, width: 2.5),
        focusedBorder: _inputBorder(jc.brand, width: 3),
        errorBorder: _inputBorder(jc.ratingAgain, width: 3),
        focusedErrorBorder: _inputBorder(jc.ratingAgain, width: 3.5),
        errorStyle: TextStyle(
          color: jc.ratingAgain,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: jc.brand,
          foregroundColor: jc.surface,
          disabledBackgroundColor: jc.brand.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white,
          textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
            side: BorderSide(color: jc.ink, width: 2.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: jc.ink,
          side: BorderSide(color: jc.ink, width: 2.5),
          textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.sm)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: jc.brand,
          textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: jc.ink,
          backgroundColor: jc.surface,
          side: BorderSide(color: jc.ink, width: 2.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: jc.brand,
        linearTrackColor: jc.surface,
        circularTrackColor: jc.surfaceAlt,
        linearMinHeight: 10,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? jc.ink : jc.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? jc.acid : jc.surfaceAlt,
        ),
        trackOutlineColor: WidgetStatePropertyAll(jc.ink),
        trackOutlineWidth: const WidgetStatePropertyAll(2.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? jc.brand : jc.ink,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? jc.brand : jc.surface,
        ),
        checkColor: WidgetStatePropertyAll(jc.surface),
        side: BorderSide(color: jc.ink, width: 2.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: jc.brand,
        inactiveTrackColor: jc.surfaceAlt,
        thumbColor: jc.acid,
        overlayColor: jc.acid.withValues(alpha: 0.2),
        trackHeight: 8,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: jc.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: jc.ink, width: 2.5),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: jc.ink,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: jc.surface, width: 2),
        ),
        textStyle: TextStyle(color: jc.surface, fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: jc.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: jc.acid,
        elevation: 0,
        height: 72,
        // Persistent labels keep five destinations clear on compact screens.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: jc.ink,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 24, color: jc.ink),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: jc.ink,
        contentTextStyle: TextStyle(
            color: jc.canvas,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: jc.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: jc.ink, width: 3),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: jc.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
          side: BorderSide(color: jc.ink, width: 3),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color c, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: c, width: width),
      );

  static TextTheme _text(TextTheme base, JibikiColors jc) {
    TextStyle s(double size, FontWeight w,
            {double h = 1.25, double ls = -0.2, Color? c}) =>
        TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: size,
            fontWeight: w,
            height: h,
            letterSpacing: ls,
            color: c ?? jc.ink);
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
    return _inner.buildTransitions(
        route, context, animation, secondaryAnimation, child);
  }
}

/// A cheap slide and fade. It only animates transform and opacity, so it stays
/// smooth on modest phones and avoids expensive blur or layout animation.
class _NeoPopTransition extends PageTransitionsBuilder {
  const _NeoPopTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.035, 0), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
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
    required this.acid,
    required this.magenta,
    required this.lime,
    required this.lavender,
    required this.coral,
  });

  final Color brand, brandPressed, brandSoft;
  final Color canvas, surface, surfaceAlt, ink, body, muted, hairline;
  final Color ratingAgain, ratingHard, ratingGood, ratingEasy;
  final Color success, warn;
  final Color acid, magenta, lime, lavender, coral;

  /// The vivid hero gradient used by progress and celebration moments.
  List<Color> get instaGradient => AppTheme.gradient;
  LinearGradient get instaLinear => AppTheme.brandGradient;

  // Light, warmth is carried by the accent, never by the body background, so the
  // base stays a true white (surfaceAlt/hairline lean a hair toward the vermilion
  // hue for cohesion, not toward cream). Every colour used as text clears WCAG AA.
  static const light = JibikiColors(
    brand: Color(0xFFD4402A), // vermilion 朱, white text 4.6:1
    brandPressed:
        Color(0xFFB4301F), // darker vermilion (pressed / text-on-soft)
    brandSoft: Color(0xFFFBEAE4), // warm wash behind brand text + icons
    canvas: Color(0xFFF4F4F6),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4F1EF), // barely-warm neutral, not cream
    ink: Color(0xFF141210), // warm near-black
    body: Color(0xFF29251F), // warm dark grey, ~13:1 on white
    muted: Color(0xFF6E6A66), // 5.4:1 on white, 4.9:1 on surfaceAlt
    hairline: Color(0xFFE3DEDA),
    ratingAgain: Color(0xFFC62828), // deep red, 5.6:1 as text
    ratingHard: Color(0xFFB45309), // burnt amber, 5.0:1 as text
    ratingGood: Color(0xFF15803D), // deep green, 5.0:1 as text
    ratingEasy: Color(0xFF5B51D8), // indigo, 5.8:1 as text
    success: Color(0xFF15803D),
    warn: Color(0xFF8B4A00),
    acid: Color(0xFFF2E51C),
    magenta: Color(0xFFFF57A8),
    lime: Color(0xFF8FE838),
    lavender: Color(0xFFC9B8F9),
    coral: Color(0xFFFF6952),
  );

  static const neopop = JibikiColors(
    brand: Color(0xFF2B36E3),
    brandPressed: Color(0xFF2029B5),
    brandSoft: Color(0xFFC9B8F9),
    canvas: Color(0xFFF4F4F6),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE9E7EF),
    ink: Color(0xFF17131F),
    body: Color(0xFF2F2A38),
    muted: Color(0xFF5D5866),
    hairline: Color(0xFF17131F),
    ratingAgain: Color(0xFFC83232),
    ratingHard: Color(0xFF8B4A00),
    ratingGood: Color(0xFF16713A),
    ratingEasy: Color(0xFF2B36E3),
    success: Color(0xFF16713A),
    warn: Color(0xFF8B4A00),
    acid: Color(0xFFF2E51C),
    magenta: Color(0xFFFF57A8),
    lime: Color(0xFF8FE838),
    lavender: Color(0xFFC9B8F9),
    coral: Color(0xFFFF6952),
  );

  static const harmonie = JibikiColors(
    brand: Color(0xFF3441D4),
    brandPressed: Color(0xFF25309E),
    brandSoft: Color(0xFFDFE3FB),
    canvas: Color(0xFFF4F4F9),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE9E3F8),
    ink: Color(0xFF1B1830),
    body: Color(0xFF302C47),
    muted: Color(0xFF5A5670),
    hairline: Color(0xFF1B1830),
    ratingAgain: Color(0xFFB93262),
    ratingHard: Color(0xFF6441B7),
    ratingGood: Color(0xFF3441D4),
    ratingEasy: Color(0xFF25309E),
    success: Color(0xFF23704A),
    warn: Color(0xFF8A4C13),
    acid: Color(0xFFF28AB4),
    magenta: Color(0xFFF28AB4),
    lime: Color(0xFFA9B6F2),
    lavender: Color(0xFFCFB9EF),
    coral: Color(0xFFE56C9F),
  );

  // Dark NeoPop keeps the same hue relationships on deep violet surfaces.
  static const dark = JibikiColors(
    brand: Color(0xFF6670FF),
    brandPressed: Color(0xFF9298FF),
    brandSoft: Color(0xFF312C68),
    canvas: Color(0xFF12101D),
    surface: Color(0xFF1D1A29),
    surfaceAlt: Color(0xFF292438),
    ink: Color(0xFFF8F7FF),
    body: Color(0xFFEEEAF4),
    muted: Color(0xFFBBB4C8),
    hairline: Color(0xFFF8F7FF),
    ratingAgain: Color(0xFFFF6B6B),
    ratingHard: Color(0xFFF5A623),
    ratingGood: Color(0xFF3DD07E),
    ratingEasy: Color(0xFF8B82F5),
    success: Color(0xFF3DD07E),
    warn: Color(0xFFF5A623),
    acid: Color(0xFFF2E51C),
    magenta: Color(0xFFFF6DB5),
    lime: Color(0xFF72C92A),
    lavender: Color(0xFF675A91),
    coral: Color(0xFFFF6952),
  );

  static const harmonieDark = JibikiColors(
    brand: Color(0xFF7B86FF),
    brandPressed: Color(0xFFA6ADFF),
    brandSoft: Color(0xFF30365F),
    canvas: Color(0xFF141321),
    surface: Color(0xFF201E31),
    surfaceAlt: Color(0xFF2C2942),
    ink: Color(0xFFF8F7FF),
    body: Color(0xFFEDEAF6),
    muted: Color(0xFFB9B4CB),
    hairline: Color(0xFFF8F7FF),
    ratingAgain: Color(0xFFFF7CAB),
    ratingHard: Color(0xFFB49AF4),
    ratingGood: Color(0xFF92A0FF),
    ratingEasy: Color(0xFF7B86FF),
    success: Color(0xFF72D79C),
    warn: Color(0xFFF1B45A),
    acid: Color(0xFFF28AB4),
    magenta: Color(0xFFF28AB4),
    lime: Color(0xFFA9B6F2),
    lavender: Color(0xFF5C477E),
    coral: Color(0xFFE56C9F),
  );

  static JibikiColors forPalette(ThemePalette palette, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return palette == ThemePalette.harmonie ? harmonieDark : dark;
    }
    return palette == ThemePalette.harmonie ? harmonie : neopop;
  }

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
      acid: m(acid, other.acid),
      magenta: m(magenta, other.magenta),
      lime: m(lime, other.lime),
      lavender: m(lavender, other.lavender),
      coral: m(coral, other.coral),
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
  static const double xs = 4,
      sm = 8,
      md = 12,
      base = 16,
      lg = 20,
      xl = 24,
      xxl = 32,
      huge = 40;
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
  static Duration timed(BuildContext c, Duration d) =>
      enabled(c) ? d : Duration.zero;
}

class Shadows {
  Shadows._();
  static List<BoxShadow> soft(BuildContext c) => [
        BoxShadow(
          color: c.jc.ink,
          blurRadius: 0,
          offset: const Offset(4, 4),
        ),
      ];
  static List<BoxShadow> lifted(BuildContext c) => [
        BoxShadow(
          color: c.jc.ink,
          blurRadius: 0,
          offset: const Offset(6, 6),
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
  JibikiColors get jc =>
      Theme.of(this).extension<JibikiColors>() ?? JibikiColors.neopop;
  TextTheme get text => Theme.of(this).textTheme;
}
