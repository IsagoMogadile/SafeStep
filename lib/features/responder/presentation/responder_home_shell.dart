import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../auth/presentation/welcome_screen.dart';
import '../data/responder_repository.dart';
import 'alert_feed_tab.dart';
import 'history_tab.dart';
import 'responder_map_tab.dart';
import 'responder_profile_tab.dart';

/// How often to re-check that this responder hasn't been deactivated by an
/// admin while the app is open — see [_ResponderHomeShellState._startStatusPoll].
const _statusPollInterval = Duration(seconds: 30);

/// Responder post-login shell (scope.md §6): 3 bottom-nav tabs mirroring
/// docs/prototype.html's rp-home / rp-history / rp-profile.
class ResponderHomeShell extends StatefulWidget {
  const ResponderHomeShell({super.key});

  @override
  State<ResponderHomeShell> createState() => _ResponderHomeShellState();
}

class _ResponderHomeShellState extends State<ResponderHomeShell> {
  final _repository = ResponderRepository();
  late final Future<Map<String, dynamic>?> _selfFuture;
  Timer? _statusPollTimer;
  bool _deactivated = false;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _selfFuture = _repository.fetchSelf(
      SupabaseService.client.auth.currentUser!.id,
    );
    _selfFuture.then((self) {
      if (!mounted) return;
      final responderId = self?['responder_id'] as String?;
      if (responderId != null && self!['status'] == 'active') {
        _startStatusPoll(responderId);
      }
    });
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    super.dispose();
  }

  /// A responder's Supabase session otherwise stays valid — and the app
  /// keeps working exactly as before — for as long as they leave it open,
  /// regardless of an admin flipping their account to inactive in the
  /// meantime. Polling (rather than a realtime subscription; this app
  /// doesn't use those, see WalkSessionRepository) is what actually
  /// notices that and kicks them out.
  void _startStatusPoll(String responderId) {
    _statusPollTimer = Timer.periodic(_statusPollInterval, (_) async {
      String? status;
      try {
        status = await _repository.fetchStatus(responderId);
      } catch (_) {
        return; // transient network error — try again next tick
      }
      if (status != 'active' && mounted) {
        _statusPollTimer?.cancel();
        // Drop anything pushed on top (e.g. mid-report, alert detail) so the
        // deactivated screen is immediately visible, not just once they
        // happen to back out of whatever they were doing.
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => _deactivated = true);
      }
    });
  }

  Future<void> _signOut() async {
    await SupabaseService.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Widget _deactivatedScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Your account has been deactivated',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'An admin has deactivated this responder account. '
                  "Contact your admin if you think this isn't right.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _signOut, child: const Text('Sign Out')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_deactivated) return _deactivatedScreen();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _selfFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final self = snapshot.data;
        if (self == null) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "Couldn't load your responder profile. Please sign out "
                  'and back in.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (self['status'] != 'active') return _deactivatedScreen();

        final responderId = self['responder_id'] as String;
        final fullName = self['full_name'] as String? ?? 'Responder';
        final org = self['organization'] == 'nmu_campus_security'
            ? 'NMU Campus Security'
            : 'Security Company';
        final zone = self['zones'] as Map<String, dynamic>?;

        return Scaffold(
          appBar: AppBar(
            title: Text(['Active Alerts', 'Map', 'History', 'Profile'][_tabIndex]),
          ),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              AlertFeedTab(responderId: responderId),
              ResponderMapTab(
                responderId: responderId,
                zoneName: zone?['name'] as String?,
                zoneLat: (zone?['lat'] as num?)?.toDouble(),
                zoneLng: (zone?['lng'] as num?)?.toDouble(),
              ),
              HistoryTab(responderId: responderId),
              ResponderProfileTab(fullName: fullName, org: org),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (index) => setState(() => _tabIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.campaign_outlined),
                selectedIcon: Icon(Icons.campaign),
                label: 'Alerts',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
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
