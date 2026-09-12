import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../auth/data/auth_repository.dart';
import 'alerts_screen.dart';
import 'home_tab.dart';
import 'map_tab.dart';
import 'profile_tab.dart';
import 'widgets/student_drawer.dart';

/// Student post-login shell: exactly 3 bottom-nav tabs (Home/Map/Profile)
/// + a header bell for alerts + a drawer for everything else, per
/// scope.md §5 "Bottom navigation" / "Home screen".
class StudentHomeShell extends StatefulWidget {
  const StudentHomeShell({super.key});

  @override
  State<StudentHomeShell> createState() => _StudentHomeShellState();
}

class _StudentHomeShellState extends State<StudentHomeShell> {
  int _tabIndex = 0;
  late final Future<Map<String, dynamic>?> _profileFuture;

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
        .select('full_name, email, faculty_year, residence_type, campuses(name)')
        .eq('student_id', userId)
        .maybeSingle();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final fullName = profile?['full_name'] as String?;
        final firstName = fullName?.split(RegExp(r'\s+')).first;
        final campusName =
            (profile?['campuses'] as Map<String, dynamic>?)?['name'] as String?;

        return Scaffold(
          appBar: AppBar(
            title: _tabIndex == 0
                ? _HomeHeaderTitle(firstName: firstName, campusName: campusName)
                : Text(_tabIndex == 1 ? 'Map' : 'Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Alerts',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          drawer: StudentDrawer(fullName: fullName),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              HomeTab(campusName: campusName),
              const MapTab(),
              const ProfileTab(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (index) => setState(() => _tabIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeHeaderTitle extends StatelessWidget {
  const _HomeHeaderTitle({this.firstName, this.campusName});

  final String? firstName;
  final String? campusName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          firstName == null ? 'Hi' : 'Hi, $firstName',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (campusName != null)
          Text(
            campusName!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Exposed so the drawer / profile tab can sign out without each needing
/// its own AuthRepository instance.
final sharedAuthRepository = AuthRepository();
