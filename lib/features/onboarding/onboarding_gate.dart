import 'package:flutter/material.dart';

import '../auth/presentation/auth_gate.dart';
import 'onboarding_prefs.dart';
import 'onboarding_screen.dart';

/// Shows the onboarding slides once on first launch, then always goes
/// straight to [AuthGate] afterward.
class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context) {
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
