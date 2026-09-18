import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../../../core/supabase/supabase_service.dart';
import '../../auth/data/auth_repository.dart';
import '../data/alert_status_poller.dart';
import '../data/alerts_seen_prefs.dart';
import '../data/safe_ride_report_poller.dart';
import '../data/walk_session_repository.dart';
import 'alerts_screen.dart';
import 'home_tab.dart';
import 'map_tab.dart';
import 'profile_tab.dart';
import 'quick_sos_screen.dart';
import 'support_screen.dart';
import 'walk_with_me/companion_invites_screen.dart';
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
  final _walkRepository = WalkSessionRepository();
  int _tabIndex = 0;
  late final Future<Map<String, dynamic>?> _profileFuture;
  late Future<int> _unreadAlertsFuture;
  late Future<int> _pendingInvitesFuture;
  StreamSubscription<Uri?>? _widgetClickSub;
  bool _openedQuickSos = false;
  AlertStatusPoller? _alertStatusPoller;
  SafeRideReportPoller? _safeRideReportPoller;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
    _unreadAlertsFuture = _fetchUnreadAlertsCount();
    _pendingInvitesFuture = _fetchPendingInviteCount();
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    final studentId = SupabaseService.client.auth.currentUser?.id;
    if (studentId != null) {
      _alertStatusPoller = AlertStatusPoller(studentId: studentId)..start();
      _safeRideReportPoller = SafeRideReportPoller(studentId: studentId)..start();
    }
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    _alertStatusPoller?.stop();
    _safeRideReportPoller?.stop();
    super.dispose();
  }

  // Fires when the app was opened (cold start) or brought to the
  // foreground (warm) by tapping the SOS home-screen widget — jumps
  // straight to the same hold-to-confirm flow as the in-app SOS button,
  // skipping Home entirely.
  void _handleWidgetUri(Uri? uri) {
    if (uri?.host != 'sos' || _openedQuickSos) return;
    _openedQuickSos = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const QuickSosScreen()));
      _openedQuickSos = false;
    });
  }

  Future<int> _fetchPendingInviteCount() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return 0;
    final invites = await _walkRepository.fetchPendingCompanionInvites(userId);
    return invites.length;
  }

  Future<void> _openCompanionInvites() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CompanionInvitesScreen()),
    );
    if (mounted) {
      setState(() { _pendingInvitesFuture = _fetchPendingInviteCount(); });
    }
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

  Future<int> _fetchUnreadAlertsCount() async {
    final lastSeen = await AlertsSeenPrefs.lastSeen();
    var query = SupabaseService.client
        .from('safety_broadcasts')
        .select('broadcast_id')
        .not('sent_at', 'is', null)
        .filter('retracted_at', 'is', null);
    if (lastSeen != null) {
      query = query.gt('sent_at', lastSeen.toIso8601String());
    }
    final rows = await query.count(CountOption.exact);
    return rows.count;
  }

  Future<void> _openAlerts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AlertsScreen()),
    );
    await AlertsSeenPrefs.markSeenNow();
    if (mounted) setState(() { _unreadAlertsFuture = _fetchUnreadAlertsCount(); });
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
                icon: const Icon(Icons.favorite_outline),
                tooltip: 'Get Support',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SupportScreen()),
                ),
              ),
              FutureBuilder<int>(
                future: _unreadAlertsFuture,
                builder: (context, unreadSnapshot) {
                  final unread = unreadSnapshot.data ?? 0;
                  return IconButton(
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text('$unread'),
                      child: const Icon(Icons.notifications_outlined),
                    ),
                    tooltip: 'Alerts',
                    onPressed: _openAlerts,
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
          drawer: StudentDrawer(fullName: fullName),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              HomeTab(
                campusName: campusName,
                pendingInvitesFuture: _pendingInvitesFuture,
                onOpenPendingInvites: _openCompanionInvites,
              ),
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
