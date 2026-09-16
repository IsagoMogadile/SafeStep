import 'package:flutter/material.dart';

import '../../../core/auth/biometric_lock_prefs.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

/// Shown in front of the student/responder/admin home whenever biometric
/// lock is turned on (Settings) and the app has just launched or
/// returned from the background — the session itself is already valid
/// (Supabase auth), this is purely a local "prove it's really you"
/// gate on top of it.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _isAuthenticating = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Prompt immediately on arrival, rather than waiting for a tap.
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _failed = false;
    });
    final success = await BiometricService.authenticate(
      reason: 'Unlock SafeStep',
    );
    if (!mounted) return;
    if (success) {
      widget.onUnlocked();
    } else {
      setState(() {
        _isAuthenticating = false;
        _failed = true;
      });
    }
  }

  // A safety app can never let someone get permanently stuck behind a
  // failed biometric prompt (wrong/unenrolled sensor, no device PIN set,
  // etc.) — that would block them from reaching the SOS button. This is
  // the escape hatch: sign out and turn the lock off, landing back on
  // the Welcome screen with no gate in front of it.
  Future<void> _signOutInstead() async {
    await BiometricLockPrefs.setEnabled(false);
    await SupabaseService.client.auth.signOut();
    if (!mounted) return;
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.seed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    size: 48,
                    color: AppColors.seed,
                  ),
                ),
                const SizedBox(height: 24),
                Text('SafeStep is locked', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  _failed
                      ? "Couldn't verify it's you — try again."
                      : 'Verify it\'s you to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                if (_isAuthenticating)
                  const CircularProgressIndicator()
                else ...[
                  ElevatedButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock'),
                  ),
                  if (_failed) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _signOutInstead,
                      child: const Text('Sign out and turn off app lock'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
