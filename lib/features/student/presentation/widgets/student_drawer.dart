import 'package:flutter/material.dart';

import '../../../auth/presentation/welcome_screen.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../../core/widgets/confirm_logout.dart';
import '../../../../core/widgets/online_only_gate.dart';
import '../groups_home_screen.dart';
import '../my_reports_screen.dart';
import '../privacy_notice_screen.dart';
import '../shuttle_library_screen.dart';
import '../trusted_contacts_screen.dart';
import '../safety_resources_screen.dart';
import '../walk_with_me/companion_invites_screen.dart';

/// Everything not on the Home screen's SOS + 4 tiles lives here
/// (scope.md §5 "Home screen"), matching docs/prototype.html's drawer.
class StudentDrawer extends StatelessWidget {
  const StudentDrawer({super.key, this.fullName});

  final String? fullName;

  String get _initials {
    final name = fullName?.trim();
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }

  Future<void> _signOut(BuildContext context) async {
    if (!await confirmLogout(context)) return;
    if (!context.mounted) return;
    await SupabaseService.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _navigateIfOnline(BuildContext context, String featureName, Widget screen) {
    Navigator.of(context).pop();
    runIfOnline(
      context,
      featureName: featureName,
      action: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      _initials,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fullName ?? 'Student',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Trusted contacts'),
                    onTap: () =>
                        _navigate(context, const TrustedContactsScreen()),
                  ),
                  OnlineOnlyDimmer(
                    child: ListTile(
                      leading: const Icon(Icons.groups_outlined),
                      title: const Text('Groups'),
                      onTap: () =>
                          _navigateIfOnline(context, 'Groups', const GroupsHomeScreen()),
                    ),
                  ),
                  OnlineOnlyDimmer(
                    child: ListTile(
                      leading: const Icon(Icons.directions_walk_outlined),
                      title: const Text('Companion invites'),
                      onTap: () => _navigateIfOnline(
                        context,
                        'Companion invites',
                        const CompanionInvitesScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Safety resources'),
                    onTap: () =>
                        _navigate(context, const SafetyResourcesScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.directions_bus_outlined),
                    title: const Text('Shuttle & library times'),
                    onTap: () =>
                        _navigate(context, const ShuttleLibraryScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('My reports'),
                    onTap: () => _navigate(context, const MyReportsScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Privacy notice'),
                    onTap: () =>
                        _navigate(context, const PrivacyNoticeScreen()),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: colorScheme.error),
              title: Text('Log Out', style: TextStyle(color: colorScheme.error)),
              onTap: () => _signOut(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
