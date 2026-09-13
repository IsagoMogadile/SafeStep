import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../auth/presentation/welcome_screen.dart';
import 'edit_profile_screen.dart';
import 'medical_info_screen.dart';
import 'my_reports_screen.dart';
import 'privacy_notice_screen.dart';
import 'settings_screen.dart';
import 'trusted_contacts_screen.dart';
import 'vehicle_mobility_screen.dart';

/// Matches docs/prototype.html's Profile screen: identity header + a menu
/// of everything account-related, plus sign out.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
  }

  Future<Map<String, dynamic>?> _fetchProfile() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;
    return SupabaseService.client
        .from('students')
        .select('full_name, email, phone, avatar_url, campuses(name)')
        .eq('student_id', userId)
        .maybeSingle();
  }

  void _refresh() => setState(() { _profileFuture = _fetchProfile(); });

  Future<void> _signOut(BuildContext context) async {
    if (!await confirmLogout(context)) return;
    await SupabaseService.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data;
        final colorScheme = Theme.of(context).colorScheme;
        final fullName = profile?['full_name'] as String? ?? 'Student';
        final avatarUrl = profile?['avatar_url'] as String?;
        final campusName =
            (profile?['campuses'] as Map<String, dynamic>?)?['name'] as String?;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            fullName
                                .trim()
                                .split(RegExp(r'\s+'))
                                .where((p) => p.isNotEmpty)
                                .map((p) => p[0])
                                .take(2)
                                .join()
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(fullName, style: Theme.of(context).textTheme.titleLarge),
                  if (campusName != null)
                    Text(
                      campusName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final saved = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                      if (saved == true) _refresh();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Profile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Trusted contacts'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _push(const TrustedContactsScreen()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.medical_information_outlined),
                    title: const Text('Medical info card'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _push(const MedicalInfoScreen()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.directions_car_outlined),
                    title: const Text('Vehicle & mobility info'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _push(const VehicleMobilityScreen()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('My reports'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _push(const MyReportsScreen()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Privacy notice'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _push(const PrivacyNoticeScreen()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _push(const SettingsScreen()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _signOut(context),
              style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }
}
