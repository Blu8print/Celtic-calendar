import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Colour palette (matches HTML prototype exactly) ─────────────────────────

class AppColors {
  AppColors._();

  static const bg       = Color(0xFF070E06);
  static const surface  = Color(0xFF0F1A0E);
  static const surface2 = Color(0xFF172615);
  static const gold     = Color(0xFFC9A84C);
  static const gold2    = Color(0xFFE8CC88);
  static const cream    = Color(0xFFEEE0BC);
  static const muted    = Color(0xFF527048);
  static const text     = Color(0xFFC0D8B8);
  static const dim      = Color(0xFF3A5030);
  static const border   = Color(0xFF1E3019);

  // Special day backgrounds
  static const todayBg   = Color(0xFF2A1508);
  static const yearDayBg = Color(0xFF100820);

  // Year Day accent colours (purple tones from HTML prototype)
  static const ydBorder  = Color(0xFF2A1050);
  static const ydTitle   = Color(0xFFC0A0F0);
  static const ydGreg    = Color(0xFF705090);
  static const ydDesc    = Color(0xFF8060B0);
  static const ydGoldBorder = gold;
}

// ─── Text styles ─────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  /// Cinzel Decorative — headings, month names.
  static TextStyle cinzelDeco({
    double size = 14,
    Color color = AppColors.gold,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.cinzelDecorative(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacing,
      );

  /// Cinzel — labels, day numbers, navigation.
  static TextStyle cinzel({
    double size = 14,
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.cinzel(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      );

  /// IM Fell English — descriptions, keywords, body text.
  static TextStyle imFell({
    double size = 14,
    Color color = AppColors.text,
    bool italic = false,
  }) =>
      GoogleFonts.imFellEnglish(
        fontSize: size,
        color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );
}

// ─── ThemeData ────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.gold,
        secondary: AppColors.gold2,
        onSurface: AppColors.text,
        onPrimary: AppColors.bg,
        outline: AppColors.border,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
        titleTextStyle: AppTextStyles.cinzelDeco(
          size: 16,
          color: AppColors.gold,
          letterSpacing: 0.15,
        ),
        centerTitle: true,
      ),
      textTheme: GoogleFonts.imFellEnglishTextTheme(base.textTheme).copyWith(
        bodyMedium: AppTextStyles.imFell(size: 14),
        bodySmall: AppTextStyles.imFell(size: 12, color: AppColors.muted),
      ),
      dividerColor: AppColors.border,
      cardColor: AppColors.surface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface2,
          foregroundColor: AppColors.gold,
          side: const BorderSide(color: AppColors.border),
          textStyle: AppTextStyles.cinzel(size: 13, letterSpacing: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        hintStyle: AppTextStyles.imFell(color: AppColors.dim),
        labelStyle: AppTextStyles.cinzel(size: 12, color: AppColors.muted),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.gold),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
