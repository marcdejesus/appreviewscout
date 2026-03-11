import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.canvas,
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.borderSoft,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.spacingUnit,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
  });

  final Color canvas;
  final Color surface0;
  final Color surface1;
  final Color surface2;
  final Color borderSoft;
  final Color border;
  final Color borderStrong;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;
  final double spacingUnit;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;

  @override
  AppThemeTokens copyWith({
    Color? canvas,
    Color? surface0,
    Color? surface1,
    Color? surface2,
    Color? borderSoft,
    Color? border,
    Color? borderStrong,
    Color? accent,
    Color? success,
    Color? warning,
    Color? error,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textMuted,
    double? spacingUnit,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
  }) {
    return AppThemeTokens(
      canvas: canvas ?? this.canvas,
      surface0: surface0 ?? this.surface0,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      borderSoft: borderSoft ?? this.borderSoft,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textMuted: textMuted ?? this.textMuted,
      spacingUnit: spacingUnit ?? this.spacingUnit,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) {
      return this;
    }
    return AppThemeTokens(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      surface0: Color.lerp(surface0, other.surface0, t) ?? surface0,
      surface1: Color.lerp(surface1, other.surface1, t) ?? surface1,
      surface2: Color.lerp(surface2, other.surface2, t) ?? surface2,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t) ?? borderSoft,
      border: Color.lerp(border, other.border, t) ?? border,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t) ?? borderStrong,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t) ?? textTertiary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      spacingUnit: _lerpDouble(spacingUnit, other.spacingUnit, t),
      radiusSm: _lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: _lerpDouble(radiusMd, other.radiusMd, t),
      radiusLg: _lerpDouble(radiusLg, other.radiusLg, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

class AppTheme {
  static const AppThemeTokens tokens = AppThemeTokens(
    canvas: Color(0xFF0F1117),
    surface0: Color(0xFF161922),
    surface1: Color(0xFF1C1F2B),
    surface2: Color(0xFF232736),
    borderSoft: Color(0xFF2A2F40),
    border: Color(0xFF343A4F),
    borderStrong: Color(0xFF46516D),
    accent: Color(0xFFE8A838),
    success: Color(0xFF34D399),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    textPrimary: Color(0xFFE5E7EB),
    textSecondary: Color(0xFFB5BCD0),
    textTertiary: Color(0xFF8B93AA),
    textMuted: Color(0xFF657089),
    spacingUnit: 4,
    radiusSm: 6,
    radiusMd: 8,
    radiusLg: 12,
  );

  static ThemeData get darkTheme {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.inter(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: -0.1),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.inter(fontWeight: FontWeight.w500),
    );

    return base.copyWith(
      scaffoldBackgroundColor: tokens.canvas,
      textTheme: textTheme.apply(
        bodyColor: tokens.textPrimary,
        displayColor: tokens.textPrimary,
      ),
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF161922),
        primary: Color(0xFFE8A838),
        secondary: Color(0xFF34D399),
        error: Color(0xFFEF4444),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border),
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.borderSoft, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          borderSide: BorderSide(color: tokens.accent),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.canvas,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      extensions: const [tokens],
    );
  }
}

extension AppThemeX on BuildContext {
  AppThemeTokens get tokens => Theme.of(this).extension<AppThemeTokens>() ?? AppTheme.tokens;
}
