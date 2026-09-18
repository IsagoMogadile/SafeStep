import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/safe_ride_repository.dart';

/// Safety broadcasts (admin-created, distinct from panic alerts — scope.md
/// §7/§9 `safety_broadcasts`). Reached via the header bell icon, not a
/// bottom tab (scope.md §5 "Bottom navigation").
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late Future<List<Map<String, dynamic>>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = _fetchAlerts();
  }

  static const _statusLabels = {
    'acknowledged': 'A responder has acknowledged your alert',
    'dispatched': 'A responder has been dispatched to you',
    'resolved': 'Your alert has been marked resolved',
    'false_alarm_verify': 'Marked as a possible false alarm — security will still check in',
  };

  Future<List<Map<String, dynamic>>> _fetchAlerts() async {
    final userId = SupabaseService.client.auth.currentUser?.id;

    final broadcastsRows = await SupabaseService.client
        .from('safety_broadcasts')
        .select()
        .not('sent_at', 'is', null)
        .filter('retracted_at', 'is', null)
        .order('sent_at', ascending: false);
    final broadcasts = List<Map<String, dynamic>>.from(broadcastsRows).map((row) {
      return {
        ...row,
        '_kind': 'broadcast',
        '_time': row['sent_at'] as String,
      };
    });

    var personal = const Iterable<Map<String, dynamic>>.empty();
    if (userId != null) {
      final ownAlertRows = await SupabaseService.client
          .from('alerts')
          .select('alert_id, alert_type, status, created_at, resolved_at')
          .eq('student_id', userId)
          .not('status', 'in', '(new)')
          .order('created_at', ascending: false)
          .limit(20);
      personal = List<Map<String, dynamic>>.from(ownAlertRows).map((row) {
        final status = row['status'] as String;
        return {
          '_kind': 'personal_alert',
          '_time': (row['resolved_at'] as String?) ?? row['created_at'] as String,
          'title': 'Your ${row['alert_type']} alert',
          'message': _statusLabels[status] ?? 'Status: $status',
          'status': status,
        };
      });
    }

    var safeRideReports = const Iterable<Map<String, dynamic>>.empty();
    if (userId != null) {
      final reportRows = await SafeRideRepository().fetchOwnReports(userId);
      safeRideReports = reportRows.where((row) => row['status'] != 'pending_review').map((row) {
        final status = row['status'] as String;
        final plate = (row['vehicle_records'] as Map?)?['plate_number'] as String?;
        return {
          '_kind': 'safe_ride_report',
          '_time': (row['reviewed_at'] as String?) ?? row['created_at'] as String,
          'title': 'Safe Ride report — ${plate ?? 'vehicle'}',
          'message': status == 'approved'
              ? 'Reviewed and approved'
              : 'Reviewed and closed',
          'status': status,
        };
      });
    }

    final combined = [...broadcasts, ...personal, ...safeRideReports];
    combined.sort((a, b) => (b['_time'] as String).compareTo(a['_time'] as String));
    return combined;
  }

  Future<void> _refresh() async {
    setState(() { _alertsFuture = _fetchAlerts(); });
  }

  (Color, IconData) _styleFor(String? level) {
    return switch (level) {
      'urgent' => (AppColors.alert, Icons.warning_amber_rounded),
      'caution' => (AppColors.caution, Icons.warning_amber_rounded),
      _ => (AppColors.seed, Icons.info_outline),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Safety Alerts')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _alertsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SkeletonList();
            }
            final alerts = snapshot.data!;
            if (alerts.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_outlined,
                            size: 40,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No safety alerts right now',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: alerts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final kind = alert['_kind'] as String;
                final (color, icon) = switch (kind) {
                  'personal_alert' => (AppColors.seed, Icons.campaign_outlined),
                  'safe_ride_report' => (AppColors.seed, Icons.directions_car_outlined),
                  _ => _styleFor(alert['level'] as String?),
                };
                final chipLabel = kind == 'broadcast'
                    ? (alert['level'] as String? ?? '').toUpperCase()
                    : (alert['status'] as String).toUpperCase();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  title: Text(alert['title'] as String? ?? ''),
                  subtitle: Text(alert['message'] as String? ?? ''),
                  trailing: Chip(
                    label: Text(chipLabel),
                    labelStyle: TextStyle(fontSize: 10, color: color),
                    backgroundColor: color.withValues(alpha: 0.12),
                    visualDensity: VisualDensity.compact,
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
