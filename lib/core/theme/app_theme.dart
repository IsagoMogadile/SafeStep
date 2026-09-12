import 'package:flutter/material.dart';

/// SafeStep visual identity: a calm, trustworthy indigo as the primary
/// brand color, with a distinct alert red reserved for panic/emergency
/// affordances so they never get confused with ordinary UI.
class AppColors {
  AppColors._();

  static const seed = Color(0xFF1A56DB);
  static const alert = Color(0xFFDC2626);
  static const caution = Color(0xFFF59E0B);
  static const safe = Color(0xFF16A34A);
}

class AppTheme {
  AppTheme._();

  static ThemeData light = _build(Brightness.light);
  static ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    // Material3's default textTheme already derives correct, theme-aware
    // colors from colorScheme (reconstructing it from a colorless geometry
    // TextTheme made headline text render nearly invisible; scaling it
    // with TextTheme.apply(fontSizeFactor:) then crashed on any style with
    // a null fontSize). Larger text for readability under stress (scope.md
    // §8) is applied via MediaQuery textScaler in app.dart instead, which
    // sidesteps both problems and composes correctly with the user's own
    // OS text-size setting.
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
        ),
      ),
    );
  }
}
