import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import 'welcome_screen.dart';

/// Shown for an authenticated session with no matching students/
/// responders/admins row — a state that could only happen before this
/// fix (the old flow created the auth account immediately, so abandoning
/// the wizard left an orphaned account). Going forward, signup defers
/// account creation until the wizard's review step is confirmed, so this
/// can no longer happen for a new signup — this screen only exists for
/// any pre-existing account stuck in that old state, and offers the only
/// safe way out: start over.
class IncompleteAccountScreen extends StatelessWidget {
  const IncompleteAccountScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await SupabaseService.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Account setup was never finished',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "This account doesn't have a completed profile. Sign out "
                  'and create a new account to start over.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _signOut(context),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
