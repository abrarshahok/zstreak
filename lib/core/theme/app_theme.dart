import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ZStreak design tokens — minimal, flat, no gradients.
/// Inspired by Linear / Raycast / Vercel: high contrast, neutral surfaces,
/// accent used only for interactive states and status indicators.
class AppColors {
  AppColors._();

  // ── Dark theme ─────────────────────────────────────────────────────────────
  // Near-black neutral base. Not violet-tinted — pure dark grey so habit
  // accent colors pop cleanly without competing with a background hue.
  static const Color background = Color(0xFF0E0E0E); // true near-black
  static const Color surface = Color(0xFF1A1A1A); // card surface
  static const Color surfaceElevated = Color(0xFF242424); // slightly raised
  static const Color border = Color(0xFF2A2A2A); // subtle divider
  static const Color accent = Color(
    0xFFB57BFF,
  ); // soft violet — kept for habit default
  static const Color textPrimary = Color(0xFFF2F2F2);
  static const Color textMuted = Color(0xFF888888);
  static const Color danger = Color(0xFFFF4D4D);

  /// Same role as [danger] but for a positive status (free-trial badges,
  /// "trending up") — used in both themes like danger is, not split into
  /// light/dark variants.
  static const Color success = Color(0xFF22C55E);

  /// Reserved for Premium/Pro-only UI — reads as a notch more special
  /// than the standard violet accent, in both themes.
  static const Color premiumGold = Color(0xFFFFB300);

  // ── Light theme ────────────────────────────────────────────────────────────
  // Pure white base. Cards are white. Background is a very light grey.
  // Accent is a rich violet that reads well on white.
  static const Color backgroundLight = Color(0xFFF7F7F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF0F0F0);
  static const Color borderLight = Color(0xFFE5E5E5);
  static const Color accentTextOnLight = Color(0xFF7C3AED);
  static const Color textPrimaryLight = Color(0xFF111111);
  static const Color textMutedLight = Color(0xFF888888);

  /// Per-habit accent colors. First entry (Violet) is the free default.
  static const List<HabitColorTheme> habitColorThemes = [
    HabitColorTheme('Violet', accent),
    HabitColorTheme('Cyan', Color(0xFF00C2FF)),
    HabitColorTheme('Lime', Color(0xFF9EE000)),
    HabitColorTheme('Magenta', Color(0xFFE040FB)),
    HabitColorTheme('Amber', Color(0xFFFFB300)),
    HabitColorTheme('Red', danger),
    HabitColorTheme('Mono', Color(0xFFCCCCCC)),
  ];
}

class HabitColorTheme {
  const HabitColorTheme(this.name, this.color);
  final String name;
  final Color color;
}

class AppTheme {
  AppTheme._();

  // Status bar stays transparent (Flutter still draws content behind it —
  // that's the intended edge-to-edge look for a top bar). The nav bar is
  // opaque instead: Android 15+/16 no longer lets an app opt out of
  // edge-to-edge, so the canvas always extends behind it regardless — an
  // opaque bar just means it reads as a normal, solid nav bar rather than
  // interactive content visibly running into a see-through one. Solid
  // content still needs its own MediaQuery.padding.bottom clearance
  // either way; this only fixes the visual look, not the layout.
  //
  // Exposed here (not just inline in appBarTheme below) so app.dart can
  // apply the same style app-wide via AnnotatedRegion for screens that
  // have no AppBar of their own (onboarding, sign-in, etc.) — an AppBar's
  // own systemOverlayStyle only takes effect while that AppBar is mounted.
  static const SystemUiOverlayStyle systemOverlayStyleDark =
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: AppColors.background,
      );

  static const SystemUiOverlayStyle systemOverlayStyleLight =
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.backgroundLight,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: AppColors.backgroundLight,
      );

  static TextTheme _brandTextTheme(TextTheme base) {
    final theme = GoogleFonts.outfitTextTheme(base);
    return theme.copyWith(
      displayLarge: theme.displayLarge?.copyWith(
        letterSpacing: -1.5,
        fontWeight: FontWeight.w800,
      ),
      displayMedium: theme.displayMedium?.copyWith(
        letterSpacing: -1,
        fontWeight: FontWeight.w800,
      ),
      displaySmall: theme.displaySmall?.copyWith(
        letterSpacing: -0.5,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: theme.headlineLarge?.copyWith(
        letterSpacing: -1,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: theme.headlineMedium?.copyWith(
        letterSpacing: -0.5,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: theme.headlineSmall?.copyWith(
        letterSpacing: -0.3,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: theme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.outfit().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        primary: AppColors.accent,
        surface: AppColors.surface,
      ),
    );
    return base.copyWith(
      textTheme: _brandTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
        contentTextStyle: GoogleFonts.outfit(
          color: AppColors.textMuted,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.accent,
          selectedForegroundColor: Colors.black,
          foregroundColor: AppColors.textMuted,
          textStyle: GoogleFonts.outfit(fontSize: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: AppColors.textMuted,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: systemOverlayStyleDark,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
    );
  }

  static ThemeData get light {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      fontFamily: GoogleFonts.outfit().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accentTextOnLight,
        brightness: Brightness.light,
        primary: AppColors.accentTextOnLight,
        surface: AppColors.surfaceLight,
      ),
    );
    return base.copyWith(
      textTheme: _brandTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimaryLight,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
        contentTextStyle: GoogleFonts.outfit(
          color: AppColors.textMutedLight,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentTextOnLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentTextOnLight,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.accentTextOnLight,
          selectedForegroundColor: Colors.white,
          foregroundColor: AppColors.textMutedLight,
          textStyle: GoogleFonts.outfit(fontSize: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryLight,
          side: const BorderSide(color: AppColors.borderLight),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.textMutedLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.accentTextOnLight,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: AppColors.textMutedLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: systemOverlayStyleLight,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
      ),
    );
  }
}
