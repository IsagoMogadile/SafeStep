import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../auth/presentation/welcome_screen.dart';
import '../data/admin_repository.dart';
import 'alerts_tab.dart';
import 'broadcasts_tab.dart';
import 'emergency_contacts_tab.dart';
import 'groups_tab.dart';
import 'overview_tab.dart';
import 'people_tab.dart';
import 'reports_tab.dart';
import 'resources_tab.dart';
import 'safe_ride_reports_tab.dart';
import 'students_tab.dart';
import 'zones_tab.dart';

const _sections = [
  (icon: Icons.dashboard_outlined, label: 'Overview'),
  (icon: Icons.campaign_outlined, label: 'Active Alerts'),
  (icon: Icons.badge_outlined, label: 'Responders & Admins'),
  (icon: Icons.map_outlined, label: 'Zones'),
  (icon: Icons.campaign_outlined, label: 'Safety Broadcasts'),
  (icon: Icons.menu_book_outlined, label: 'Resources'),
  (icon: Icons.report_outlined, label: 'Incident Reports'),
  (icon: Icons.directions_car_outlined, label: 'Safe Ride Reports'),
  (icon: Icons.groups_outlined, label: 'Walking Groups'),
  (icon: Icons.call_outlined, label: 'Emergency Contacts'),
  (icon: Icons.school_outlined, label: 'Students'),
];

/// Admin post-login shell (scope.md §7) — web-only, so a side
/// NavigationRail rather than the bottom-nav pattern the mobile student
/// and responder shells use.
class AdminHomeShell extends StatefulWidget {
  const AdminHomeShell({super.key});

  @override
  State<AdminHomeShell> createState() => _AdminHomeShellState();
}

class _AdminHomeShellState extends State<AdminHomeShell> {
  final _repository = AdminRepository();
  late final Future<Map<String, dynamic>?> _selfFuture;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _selfFuture = _repository.fetchSelf(
      SupabaseService.client.auth.currentUser!.id,
    );
  }

  Future<void> _signOut() async {
    if (!await confirmLogout(context)) return;
    await SupabaseService.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _selfFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final self = snapshot.data;
        if (self == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Couldn't load your admin profile. Please sign out "
                      'and back in.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _signOut,
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final adminId = self['admin_id'] as String;
        final fullName = self['full_name'] as String? ?? 'Admin';

        return Scaffold(
          appBar: AppBar(
            title: Text(_sections[_index].label),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(child: Text(fullName)),
              ),
              IconButton(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final section in _sections)
                    NavigationRailDestination(
                      icon: Icon(section.icon),
                      label: Text(
                        section.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    OverviewTab(onNavigateToSection: (i) => setState(() => _index = i)),
                    const AlertsTab(),
                    const PeopleTab(),
                    const ZonesTab(),
                    BroadcastsTab(adminId: adminId),
                    const ResourcesTab(),
                    const ReportsTab(),
                    const SafeRideReportsTab(),
                    const GroupsTab(),
                    const EmergencyContactsTab(),
                    const StudentsTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
