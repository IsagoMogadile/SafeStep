import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/location/route_service.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../data/walk_session_repository.dart';
import 'companion_meeting_screen.dart';
import 'widgets/route_map_view.dart';

/// The companion's side of "Invite a companion" (scope.md §5: "they must
/// accept before the journey starts"). Lists every pending invite where
/// the signed-in student is the invited companion, with a real planned
/// route preview and an Accept action.
class CompanionInvitesScreen extends StatefulWidget {
  const CompanionInvitesScreen({super.key});

  @override
  State<CompanionInvitesScreen> createState() => _CompanionInvitesScreenState();
}

class _CompanionInvitesScreenState extends State<CompanionInvitesScreen> {
  final _repository = WalkSessionRepository();
  late Future<List<Map<String, dynamic>>> _invitesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _invitesFuture = _repository.fetchPendingCompanionInvites(
        SupabaseService.client.auth.currentUser!.id,
      );
    });
  }

  /// Accepting asks the companion for their own location, so a meeting
  /// point roughly midway between them and the walker can be computed —
  /// the companion walks there first rather than just watching the
  /// walker go straight to the destination.
  Future<void> _accept(String sessionId, Map<String, dynamic> invite) async {
    final companionPosition = await LocationService.getCurrentLocation();
    if (!mounted) return;
    if (companionPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "We couldn't get your location, so a meeting point can't be planned. "
            "You'll still be able to watch their journey.",
          ),
        ),
      );
    }

    LatLng? meetingPoint;
    if (companionPosition != null) {
      final walkerLat = (invite['current_lat'] ?? invite['start_lat']) as num?;
      final walkerLng = (invite['current_lng'] ?? invite['start_lng']) as num?;
      if (walkerLat != null && walkerLng != null) {
        final walkerPoint = LatLng(walkerLat.toDouble(), walkerLng.toDouble());
        final companionPoint = LatLng(companionPosition.latitude, companionPosition.longitude);
        if (RouteService.distanceMeters(walkerPoint, companionPoint) <=
            RouteService.maxMeetingPointDistanceMeters) {
          meetingPoint = RouteService.midpoint(walkerPoint, companionPoint);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "You and your friend are too far apart for a shared meeting point — "
                "you'll watch their journey straight to the destination instead.",
              ),
            ),
          );
        }
      }
    }

    await _repository.acceptCompanionInvite(
      sessionId,
      companionLat: companionPosition?.latitude,
      companionLng: companionPosition?.longitude,
      meetingLat: meetingPoint?.latitude,
      meetingLng: meetingPoint?.longitude,
    );
    if (!mounted) return;
    // Straight into the live map rather than just a snackbar — that's
    // the whole point of accepting.
    final session = await _repository.fetchSession(sessionId);
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => companionTrackingScreenFor(session)),
      );
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Companion Invites')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _invitesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SkeletonList();
            }
            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }
            final invites = snapshot.data ?? [];
            if (invites.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No pending invites right now.')),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invites.length,
              itemBuilder: (context, index) => _InviteCard(
                invite: invites[index],
                onAccept: () =>
                    _accept(invites[index]['session_id'] as String, invites[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invite, required this.onAccept});

  final Map<String, dynamic> invite;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final inviterName = (invite['students'] as Map?)?['full_name'] as String? ?? 'A friend';
    final destination = invite['destination'] as String? ?? '';
    final startLat = invite['start_lat'] as num?;
    final startLng = invite['start_lng'] as num?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.directions_walk)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$inviterName invited you to Safe Walks',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'Destination: $destination',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (startLat != null && startLng != null && destination.isNotEmpty) ...[
              const SizedBox(height: 12),
              RouteMapView(
                origin: LatLng(startLat.toDouble(), startLng.toDouble()),
                destinationQuery: destination,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Accept & Watch Journey'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
