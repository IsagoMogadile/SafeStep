import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../auth/presentation/auth_gate.dart';
import 'onboarding_prefs.dart';
import 'onboarding_screen.dart';

/// Shows the onboarding slides once on first launch, then always goes
/// straight to [AuthGate] afterward. Role isn't known yet at this point
/// (onboarding runs before sign-in), so per-role skipping isn't possible
/// here — but the carousel itself is a phone-safety-feature walkthrough
/// that makes no sense on the web/admin surface (scope.md §2: admin is
/// web-only), so it's skipped outright whenever kIsWeb.
class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const AuthGate();

    return FutureBuilder<bool>(
      future: OnboardingPrefs.hasSeenOnboarding(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const AuthGate() : const OnboardingScreen();
      },
    );
  }
}
