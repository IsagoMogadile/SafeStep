import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/onboarding/onboarding_gate.dart';

class SafeStepApp extends StatelessWidget {
  const SafeStepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'SafeStep',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          // Defaults to System (follows the phone's OS setting) but is
          // overridable from Settings and persisted — see
          // ThemeController.
          themeMode: themeMode,
          // Slightly larger than the OS default for readability under
          // stress (scope.md §8), composed on top of the user's own
          // text-size setting rather than replacing it.
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(
                  mediaQuery.textScaler.scale(1.0) * 1.05,
                ),
              ),
              child: child!,
            );
          },
          home: const OnboardingGate(),
        );
      },
    );
  }
}
