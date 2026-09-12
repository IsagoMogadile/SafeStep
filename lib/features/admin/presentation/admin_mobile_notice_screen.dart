import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../auth/presentation/welcome_screen.dart';

/// Admin is web-only (scope.md §2) — if an admin account somehow opens the
/// mobile app, tell them plainly rather than showing a broken dashboard.
class AdminMobileNoticeScreen extends StatelessWidget {
  const AdminMobileNoticeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    if (!await confirmLogout(context)) return;
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
                const Icon(Icons.desktop_windows_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Admin dashboard is web-only',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account is activated. Please use the SafeStep admin '
                  'dashboard on the web to manage responders, zones, and '
                  'alerts.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
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
