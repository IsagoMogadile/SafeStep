import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../data/responder_repository.dart';
import 'alert_feed_tab.dart';
import 'history_tab.dart';
import 'responder_profile_tab.dart';

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
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _selfFuture = _repository.fetchSelf(
      SupabaseService.client.auth.currentUser!.id,
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

        final responderId = self['responder_id'] as String;
        final fullName = self['full_name'] as String? ?? 'Responder';
        final org = self['organization'] == 'nmu_campus_security'
            ? 'NMU Campus Security'
            : 'Security Company';

        return Scaffold(
          appBar: AppBar(
            title: Text(['Active Alerts', 'History', 'Profile'][_tabIndex]),
          ),
          body: IndexedStack(
            index: _tabIndex,
            children: [
              AlertFeedTab(responderId: responderId),
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
