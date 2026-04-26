import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ─── Colour palette ────────────────────────────────────────────────────────────

class AppColors {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color gold;
  final Color gold2;
  final Color cream;
  final Color muted;
  final Color text;
  final Color dim;
  final Color border;
  final Color todayBg;
  final Color yearDayBg;
  final Color ydBorder;
  final Color ydTitle;
  final Color ydGreg;
  final Color ydDesc;

  Color get ydGoldBorder => gold;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.gold,
    required this.gold2,
    required this.cream,
    required this.muted,
    required this.text,
    required this.dim,
    required this.border,
    required this.todayBg,
    required this.yearDayBg,
    required this.ydBorder,
    required this.ydTitle,
    required this.ydGreg,
    required this.ydDesc,
  });

  // ── Dark palette (original forest theme) ─────────────────────────────────────
  static const dark = AppColors(
    bg:        Color(0xFF070E06),
    surface:   Color(0xFF0F1A0E),
    surface2:  Color(0xFF172615),
    gold:      Color(0xFFC9A84C),
    gold2:     Color(0xFFE8CC88),
    cream:     Color(0xFFEEE0BC),
    muted:     Color(0xFF527048),
    text:      Color(0xFFC0D8B8),
    dim:       Color(0xFF6A8A60),
    border:    Color(0xFF1E3019),
    todayBg:   Color(0xFF0D1F0C),
    yearDayBg: Color(0xFF100820),
    ydBorder:  Color(0xFF2A1050),
    ydTitle:   Color(0xFFC0A0F0),
    ydGreg:    Color(0xFF705090),
    ydDesc:    Color(0xFF8060B0),
  );

  // ── Light palette (roots-calendar-light-v2.html) ─────────────────────────────
  static const light = AppColors(
    bg:        Color(0xFFf7f3ec),
    surface:   Color(0xFFffffff),
    surface2:  Color(0xFFf0ece4),
    gold:      Color(0xFFb07800),
    gold2:     Color(0xFF3a3226),
    cream:     Color(0xFFffffff),
    muted:     Color(0xFF1a4018),
    text:      Color(0xFF111108),
    dim:       Color(0xFF5a5040),
    border:    Color(0xFFb8ae9e),
    todayBg:   Color(0xFFe4ede2),
    yearDayBg: Color(0xFFf0ecf8),
    ydBorder:  Color(0xFFc8b8e8),
    ydTitle:   Color(0xFF5a2090),
    ydGreg:    Color(0xFF7050a0),
    ydDesc:    Color(0xFF8060b0),
  );
}

// BuildContext convenience accessor — use inside build() methods only.
extension AppColorsX on BuildContext {
  AppColors get colors => watch<AppColors>();
}

// ─── Text styles ──────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  /// Cinzel Decorative — headings, month names.
  static TextStyle cinzelDeco({
    double size = 14,
    Color? color,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.cinzelDecorative(
        fontSize: size,
        color: color ?? AppColors.dark.gold,
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacing,
      );

  /// Cinzel — labels, day numbers, navigation.
  static TextStyle cinzel({
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.cinzel(
        fontSize: size,
        color: color ?? AppColors.dark.text,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      );

  /// IM Fell English — descriptions, keywords, body text.
  static TextStyle imFell({
    double size = 14,
    Color? color,
    bool italic = false,
  }) =>
      GoogleFonts.imFellEnglish(
        fontSize: size,
        color: color ?? AppColors.dark.text,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );
}

// ─── ThemeData ────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();


  static ThemeData get dark {
    final c = AppColors.dark;
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme.dark(
        surface: c.surface,
        primary: c.gold,
        secondary: c.gold2,
        onSurface: c.text,
        onPrimary: c.bg,
        outline: c.border,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.gold),
        titleTextStyle: AppTextStyles.cinzelDeco(
          size: 16,
          color: c.gold,
          letterSpacing: 0.15,
        ),
        centerTitle: true,
      ),
      textTheme: GoogleFonts.imFellEnglishTextTheme(base.textTheme).copyWith(
        bodyMedium: AppTextStyles.imFell(size: 14, color: c.text),
        bodySmall: AppTextStyles.imFell(size: 12, color: c.muted),
      ),
      dividerColor: c.border,
      cardColor: c.surface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.surface2,
          foregroundColor: c.gold,
          side: BorderSide(color: c.border),
          textStyle: AppTextStyles.cinzel(size: 13, letterSpacing: 0.05, color: c.gold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        hintStyle: AppTextStyles.imFell(color: c.dim, size: 14),
        labelStyle: AppTextStyles.cinzel(size: 12, color: c.muted),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.gold),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  static ThemeData get light {
    final c = AppColors.light;
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme.light(
        surface: c.surface,
        primary: c.gold,
        secondary: c.muted,
        onSurface: c.text,
        onPrimary: Colors.white,
        outline: c.border,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
        iconTheme: IconThemeData(color: c.muted),
        titleTextStyle: AppTextStyles.cinzel(
          size: 15,
          color: c.text,
          weight: FontWeight.w700,
        ),
        centerTitle: false,
      ),
      textTheme: GoogleFonts.imFellEnglishTextTheme(base.textTheme).copyWith(
        bodyMedium: AppTextStyles.imFell(size: 14, color: c.text),
        bodySmall: AppTextStyles.imFell(size: 12, color: c.muted),
      ),
      dividerColor: c.border,
      cardColor: c.surface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.surface2,
          foregroundColor: c.gold2,
          side: BorderSide(color: c.border),
          textStyle: AppTextStyles.cinzel(size: 13, letterSpacing: 0.05, color: c.gold2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: AppTextStyles.imFell(color: c.dim, size: 14),
        labelStyle: AppTextStyles.cinzel(size: 12, color: c.muted),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.gold),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
