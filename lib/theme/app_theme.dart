import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:routine/theme/app_semantic_colors.dart';

class AppTheme {
  static const Color _primary = Color(0xFF0B3B66);
  static const Color _secondary = Color(0xFF0B7D83);
  static const Color _tertiary = Color(0xFFC0782C);
  static const Color _surface = Color(0xFFF7F9F8);
  static const Color _onSurface = Color(0xFF14212B);

  static const ColorScheme _lightColorScheme = ColorScheme.light(
    primary: _primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDDECF5),
    onPrimaryContainer: Color(0xFF062B49),
    secondary: _secondary,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFDDF3F1),
    onSecondaryContainer: Color(0xFF075356),
    tertiary: _tertiary,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFEEDB),
    onTertiaryContainer: Color(0xFF623B13),
    error: Color(0xFFB42318),
    onError: Colors.white,
    errorContainer: Color(0xFFFFE4E0),
    onErrorContainer: Color(0xFF7A271A),
    surface: _surface,
    onSurface: _onSurface,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF2F6F4),
    surfaceContainer: Color(0xFFECF2F0),
    surfaceContainerHigh: Color(0xFFE4ECE9),
    surfaceContainerHighest: Color(0xFFDCE6E3),
    onSurfaceVariant: Color(0xFF526168),
    outline: Color(0xFF75848A),
    outlineVariant: Color(0xFFCDD8D5),
  );

  // Sora: display/headline/title — tem peso 800 (ExtraBold) nativo, usado
  // em vários pontos do app (ex.: números do calendário, chip de streak);
  // fontes tipo Space Grotesk/Manrope param em 700 e forçariam negrito
  // sintético nesses lugares.
  static TextStyle _display(
    TextStyle? base, {
    required FontWeight weight,
    required double letterSpacing,
  }) =>
      GoogleFonts.sora(
        textStyle: base,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: _onSurface,
      );

  // Inter: body/label — números tabulares, importante pro app ser cheio de
  // strings de hora ("21:40 - 21:41") e números de dia no calendário.
  static TextStyle _body(
    TextStyle? base, {
    FontWeight? weight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) =>
      GoogleFonts.inter(
        textStyle: base,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
        color: color ?? _onSurface,
      );

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: _lightColorScheme,
      scaffoldBackgroundColor: _surface,
      canvasColor: _surface,
      fontFamily: GoogleFonts.inter().fontFamily,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: _display(base.textTheme.displayLarge,
          weight: FontWeight.w800, letterSpacing: -0.5),
      displayMedium: _display(base.textTheme.displayMedium,
          weight: FontWeight.w800, letterSpacing: -0.4),
      displaySmall: _display(base.textTheme.displaySmall,
          weight: FontWeight.w700, letterSpacing: -0.3),
      headlineLarge: _display(base.textTheme.headlineLarge,
          weight: FontWeight.w700, letterSpacing: -0.3),
      headlineMedium: _display(base.textTheme.headlineMedium,
          weight: FontWeight.w700, letterSpacing: -0.2),
      headlineSmall: _display(base.textTheme.headlineSmall,
          weight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge: _display(base.textTheme.titleLarge,
          weight: FontWeight.w800, letterSpacing: -0.2),
      titleMedium: _display(base.textTheme.titleMedium,
          weight: FontWeight.w700, letterSpacing: -0.1),
      titleSmall: _display(base.textTheme.titleSmall,
          weight: FontWeight.w600, letterSpacing: -0.1),
      bodyLarge: _body(base.textTheme.bodyLarge, height: 1.35),
      bodyMedium: _body(base.textTheme.bodyMedium,
          height: 1.35, color: _onSurface.withValues(alpha: 0.88)),
      bodySmall: _body(base.textTheme.bodySmall,
          height: 1.3, color: _onSurface.withValues(alpha: 0.70)),
      labelLarge: _body(base.textTheme.labelLarge,
          weight: FontWeight.w700, letterSpacing: 0.1),
      labelMedium: _body(base.textTheme.labelMedium, weight: FontWeight.w600),
      labelSmall: _body(base.textTheme.labelSmall,
          weight: FontWeight.w600, color: _onSurface.withValues(alpha: 0.75)),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: _primary.withValues(alpha: 0.10),
        elevation: 0.7,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _primary.withValues(alpha: 0.06)),
        ),
      ),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _primary.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _primary.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _secondary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: _primary.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: _primary.withValues(alpha: 0.08),
        thickness: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: _primary.withValues(alpha: 0.10)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      extensions: const [AppSemanticColors.light],
    );
  }
}
