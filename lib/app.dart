import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/accessibility/font_scale_controller.dart';
import 'core/l10n/app_locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/onboarding/onboarding_gate.dart';

/// Languages Flutter's own built-in Material/Cupertino widget
/// translations ship for — used only to decide whether MaterialApp's
/// `locale` can be set directly (an unsupported locale there throws).
/// SafeStep's own translated safety strings (core/l10n/app_strings.dart)
/// work for all six supported languages regardless of this list, since
/// they don't go through Flutter's Localizations lookup at all.
const _materialSupportedCodes = {'en', 'af', 'zu'};

class SafeStepApp extends StatelessWidget {
  const SafeStepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, themeMode, child) {
        return ValueListenableBuilder<double>(
          valueListenable: FontScaleController.instance,
          builder: (context, fontScale, child) {
            return ValueListenableBuilder<Locale?>(
              valueListenable: AppLocaleController.instance,
              builder: (context, locale, child) {
                return MaterialApp(
              title: 'SafeStep',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              locale: locale != null &&
                      _materialSupportedCodes.contains(locale.languageCode)
                  ? locale
                  : null,
              supportedLocales: supportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              // Defaults to System (follows the phone's OS setting) but is
              // overridable from Settings and persisted — see
              // ThemeController.
              themeMode: themeMode,
              // Slightly larger than the OS default for readability under
              // stress (scope.md §8), then the user's own in-app font-size
              // preference (Settings > Accessibility) on top of that —
              // composed with, never replacing, the OS text-size setting.
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(
                      mediaQuery.textScaler.scale(1.0) * 1.05 * fontScale,
                    ),
                  ),
                  child: child!,
                );
              },
              home: const OnboardingGate(),
                );
              },
            );
          },
        );
      },
    );
  }
}
