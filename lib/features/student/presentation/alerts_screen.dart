import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/staleness_banner.dart';
import '../data/alerts_cache.dart';
import '../data/dismissed_alerts_prefs.dart';
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
  List<Map<String, dynamic>>? _alerts;
  Object? _error;
  bool _isStale = false;
  DateTime? _cachedAt;

  static final _timeFormat = DateFormat('d MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final alerts = await _fetchAlerts();
      await AlertsCache.save(alerts);
      if (mounted) {
        setState(() {
          _alerts = alerts;
          _error = null;
          _isStale = false;
        });
      }
    } catch (e) {
      final (cached, cachedAt) = await AlertsCache.load();
      if (cached.isEmpty) {
        if (mounted) setState(() => _error = e);
        return;
      }
      // Nothing to fall back to — a real error, not just "offline".
      if (mounted) {
        setState(() {
          _alerts = cached;
          _error = null;
          _isStale = true;
          _cachedAt = cachedAt;
        });
      }
    }
  }

  static const _statusLabels = {
    'acknowledged': 'A responder has acknowledged your alert',
    'dispatched': 'A responder has been dispatched to you',
    'resolved': 'Your alert has been marked resolved',
    'false_alarm_verify': 'Marked as a possible false alarm — security will still check in',
  };

  Future<List<Map<String, dynamic>>> _fetchAlerts() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    final dismissedIds = await DismissedAlertsPrefs.all();

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
          .select('alert_id, alert_type, status, triggered_at, resolved_at')
          .eq('student_id', userId)
          .not('status', 'in', '(new)')
          .order('triggered_at', ascending: false)
          .limit(20);
      personal = List<Map<String, dynamic>>.from(ownAlertRows)
          .where((row) => !dismissedIds.contains(row['alert_id'] as String))
          .map((row) {
            final status = row['status'] as String;
            return {
              '_kind': 'personal_alert',
              'id': row['alert_id'] as String,
              '_time': (row['resolved_at'] as String?) ?? row['triggered_at'] as String,
              'title': 'Your ${row['alert_type']} alert',
              'message': _statusLabels[status] ?? 'Status: $status',
              'status': status,
              'triggeredAt': row['triggered_at'] as String,
              'resolvedAt': row['resolved_at'] as String?,
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

  Future<void> _refresh() => _load();

  (Color, IconData) _styleFor(String? level) {
    return switch (level) {
      'urgent' => (AppColors.alert, Icons.warning_amber_rounded),
      'caution' => (AppColors.caution, Icons.warning_amber_rounded),
      _ => (AppColors.seed, Icons.info_outline),
    };
  }

  void _openDetail(Map<String, dynamic> alert, Color color, IconData icon, String chipLabel) {
    final kind = alert['_kind'] as String;
    final title = alert['title'] as String? ?? '';
    final message = alert['message'] as String? ?? '';

    String timeLabel;
    if (kind == 'personal_alert') {
      final triggered = _timeFormat.format(DateTime.parse(alert['triggeredAt'] as String).toLocal());
      final resolvedAtRaw = alert['resolvedAt'] as String?;
      timeLabel = resolvedAtRaw == null
          ? 'Triggered $triggered'
          : 'Triggered $triggered · Resolved '
                '${_timeFormat.format(DateTime.parse(resolvedAtRaw).toLocal())}';
    } else {
      final time = _timeFormat.format(DateTime.parse(alert['_time'] as String).toLocal());
      timeLabel = kind == 'broadcast' ? 'Sent $time' : 'Reviewed $time';
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(chipLabel),
                  labelStyle: TextStyle(fontSize: 11, color: color),
                  backgroundColor: color.withValues(alpha: 0.12),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: 16),
                Text(message, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                Text(
                  timeLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Safety Alerts')),
      body: Column(
        children: [
          if (_isStale) StalenessBanner(lastUpdated: _cachedAt),
          Expanded(
            child: RefreshIndicator(
        onRefresh: _refresh,
        child: Builder(
          builder: (context) {
            if (_error != null) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 40, color: colorScheme.error),
                          const SizedBox(height: 12),
                          const Text("Couldn't load alerts. Pull down to try again."),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            if (_alerts == null) {
              return const SkeletonList();
            }
            final alerts = _alerts!;
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

                final tile = ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  title: Text(alert['title'] as String? ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(chipLabel),
                        labelStyle: TextStyle(fontSize: 10, color: color),
                        backgroundColor: color.withValues(alpha: 0.12),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18, color: colorScheme.outline),
                    ],
                  ),
                  onTap: () => _openDetail(alert, color, icon, chipLabel),
                );

                // Only a student's own alert history can be swiped away —
                // admin broadcasts stay put, since they aren't this
                // student's to delete.
                if (kind != 'personal_alert') {
                  return KeyedSubtree(
                    key: ValueKey('${kind}_${alert['_time']}_${alert['title']}'),
                    child: tile,
                  );
                }

                final alertId = alert['id'] as String;
                return Dismissible(
                  key: ValueKey('personal_alert_$alertId'),
                  direction: DismissDirection.startToEnd,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: colorScheme.errorContainer,
                    child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
                  ),
                  onDismissed: (_) {
                    setState(() => _alerts!.removeWhere((a) => a['id'] == alertId));
                    DismissedAlertsPrefs.dismiss(alertId);
                  },
                  child: tile,
                );
              },
            );
          },
        ),
      ),
          ),
        ],
      ),
    );
  }
}
