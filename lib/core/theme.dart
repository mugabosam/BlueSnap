/// BlueSnap Theme — warm light, Instagram-quality
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BlueSnapTheme {
  // ── Brand Colors ─────────────────────────────────────
  static const Color primary = Color(0xFF0A84FF);
  static const Color primaryLight = Color(0xFF5AB2FF);
  static const Color primaryDark = Color(0xFF0066CC);
  static const Color accent = Color(0xFF0A84FF);
  static const Color accentGreen = Color(0xFF30D158);
  static const Color accentOrange = Color(0xFFFF9F0A);
  static const Color accentRed = Color(0xFFFF3B30);
  static const Color accentPurple = Color(0xFFC13584);

  // ── Light Theme Surfaces ─────────────────────────────
  // Depth comes from these background steps, NOT from shadows.
  static const Color bgPrimary = Color(0xFFFAFAF8); // warm off-white (scaffold)
  static const Color bgSecondary = Color(0xFFFFFFFF); // nav / header
  static const Color bgCard = Color(0xFFFFFFFF); // surface 1 — cards, modals
  static const Color bgInput = Color(0xFFF2F2F0); // surface 2 — inputs, search
  static const Color bgElevated = Color(0xFFE8E8E6); // surface 3 — pressed states

  // ── Semantic aliases (spec names) ────────────────────
  static const Color surface1 = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF2F2F0);
  static const Color surface3 = Color(0xFFE8E8E6);

  // ── Text ─────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A); // near-black
  static const Color textSecondary = Color(0xFF737373);
  static const Color textTertiary = Color(0xFFA3A3A3);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Borders & Dividers ───────────────────────────────
  static const Color divider = Color(0xFFEBEBEB);
  static const Color border = Color(0xFFEBEBEB);

  // ── Accents ──────────────────────────────────────────
  static const Color likeRed = Color(0xFFFF3040);
  static const Color onlineGreen = Color(0xFF30D158);

  // Legacy signal colors (kept so any stragglers compile; not shown to users)
  static const Color signalStrong = Color(0xFF30D158);
  static const Color signalMedium = Color(0xFFFF9F0A);
  static const Color signalWeak = Color(0xFFFF3B30);

  // ── Gradients ────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0A84FF), Color(0xFF0A84FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Instagram's exact warm story-ring gradient (orange → red → pink → purple).
  static const LinearGradient storyGradient = LinearGradient(
    colors: [
      Color(0xFFF77737),
      Color(0xFFFD1D1D),
      Color(0xFFE1306C),
      Color(0xFFC13584),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient radarGradient = LinearGradient(
    colors: [Color(0xFF0A84FF), Color(0x000A84FF)],
    begin: Alignment.center,
    end: Alignment.bottomCenter,
  );

  // ── Text Styles ──────────────────────────────────────
  // Inter: bundled offline in assets/fonts (zero-internet friendly).
  static const String fontFamily = 'Inter';

  static const TextStyle headingXL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.15,
  );

  static const TextStyle headingL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const TextStyle headingM = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.2,
  );

  static const TextStyle headingS = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle bodyL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyM = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.35,
  );

  static const TextStyle bodyS = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.35,
  );

  /// Username / semibold name style.
  static const TextStyle username = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );

  /// Uppercase timestamp, e.g. "2 HOURS AGO".
  static const TextStyle timestamp = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    letterSpacing: 0.3,
    height: 1.2,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );

  /// Number displays use tabular figures so digits don't jitter.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  // ── Elevation / Depth ────────────────────────────────
  // NO shadows anywhere — depth is conveyed by background color steps.
  static List<BoxShadow> get shadowSm => const [];
  static List<BoxShadow> get shadowMd => const [];
  static List<BoxShadow> glow(Color color, {double opacity = 0.35}) => const [];

  // ── Border Radius ────────────────────────────────────
  static const double radiusS = 8;
  static const double radiusM = 10;
  static const double radiusL = 12;
  static const double radiusXL = 16;
  static const double radiusFull = 999;

  // ── Spacing ──────────────────────────────────────────
  static const double spaceXS = 4;
  static const double spaceS = 8;
  static const double spaceM = 12;
  static const double spaceL = 16;
  static const double spaceXL = 24;
  static const double spaceXXL = 32;
  static const double spaceXXXL = 48;

  // ── ThemeData ────────────────────────────────────────
  static ThemeData get theme => ThemeData(
        brightness: Brightness.light,
        fontFamily: fontFamily,
        scaffoldBackgroundColor: bgPrimary,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: primary,
          surface: bgCard,
          error: accentRed,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgSecondary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: headingL,
          iconTheme: IconThemeData(color: textPrimary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgInput,
          hintStyle: bodyM.copyWith(color: textTertiary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusM),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusM),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusM),
            borderSide: BorderSide(
              color: primary.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: divider,
          thickness: 0.5,
          space: 0,
        ),
        iconTheme: const IconThemeData(color: textPrimary, size: 24),
      );
}

// ── Extensions ───────────────────────────────────────────
extension ContextTheme on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  MediaQueryData get mq => MediaQuery.of(this);
  double get screenWidth => mq.size.width;
  double get screenHeight => mq.size.height;
  EdgeInsets get padding => mq.padding;
}
