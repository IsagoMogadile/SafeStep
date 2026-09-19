import 'package:flutter/material.dart';

import '../../../../core/supabase/supabase_service.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../data/walk_session_repository.dart';
import 'monitor_tracking_screen.dart';

/// Every active "Monitor My Journey" session where the signed-in student
/// was picked as a monitor — the counterpart to CompanionInvitesScreen,
/// minus an accept step since a monitor doesn't need to opt in before
/// watching.
class MonitoredJourneysScreen extends StatefulWidget {
  const MonitoredJourneysScreen({super.key});

  @override
  State<MonitoredJourneysScreen> createState() => _MonitoredJourneysScreenState();
}

class _MonitoredJourneysScreenState extends State<MonitoredJourneysScreen> {
  final _repository = WalkSessionRepository();
  late Future<List<Map<String, dynamic>>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _sessionsFuture = _repository.fetchActiveMonitoredSessions(
        SupabaseService.client.auth.currentUser!.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journeys You Monitor')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _sessionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SkeletonList();
            }
            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }
            final sessions = snapshot.data ?? [];
            if (sessions.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No one you monitor is on a journey right now.')),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final name = (session['students'] as Map?)?['full_name'] as String? ?? 'A friend';
                final destination = session['destination'] as String? ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.directions_walk)),
                    title: Text('$name — walking to $destination'),
                    subtitle: const Text('Tap to track on the map'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MonitorTrackingScreen(session: session),
                        ),
                      );
                      _refresh();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
