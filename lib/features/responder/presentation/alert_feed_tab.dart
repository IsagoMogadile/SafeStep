import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/responder_repository.dart';
import 'alert_detail_screen.dart';

const _statusBadge = {
  'new': ('New', AppColors.seed),
  'acknowledged': ('Acknowledged', AppColors.caution),
  'dispatched': ('Dispatched', Color(0xFF7C3AED)),
};

const _typeLabel = {
  'panic': 'Panic alert',
  'silent': 'Silent alert',
  'walk_escalation': 'Check-in missed',
};

/// scope.md §6 "Home": feed of active alerts. Zone-scoping isn't wired
/// (see AlertRepository), so this shows every alert this responder was
/// fanned out to, in `alert_recipients` order.
class AlertFeedTab extends StatefulWidget {
  const AlertFeedTab({super.key, required this.responderId});

  final String responderId;

  @override
  State<AlertFeedTab> createState() => _AlertFeedTabState();
}

class _AlertFeedTabState extends State<AlertFeedTab> {
  final _repository = ResponderRepository();
  late Future<List<Map<String, dynamic>>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = _repository.fetchOpenAlerts(widget.responderId);
  }

  Future<void> _refresh() async {
    setState(() {
      _alertsFuture = _repository.fetchOpenAlerts(widget.responderId);
    });
  }

  String _elapsedLabel(String triggeredAt) {
    final elapsed = DateTime.now().difference(DateTime.parse(triggeredAt));
    final minutes = elapsed.inMinutes;
    return minutes < 1 ? 'just now' : '$minutes min elapsed';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _alertsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text(
                      'No active alerts',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              final alert = row['alerts'] as Map<String, dynamic>;
              final student = alert['students'] as Map<String, dynamic>?;
              final zone = alert['zones'] as Map<String, dynamic>?;
              final status = alert['status'] as String? ?? 'new';
              final (label, color) = _statusBadge[status] ?? ('New', AppColors.seed);
              final isSilent = alert['alert_type'] == 'silent';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    isSilent ? Icons.visibility_off_outlined : Icons.campaign_outlined,
                    color: color,
                    size: 18,
                  ),
                ),
                title: Text(
                  '${_typeLabel[alert['alert_type']] ?? 'Alert'} — '
                  '${student?['full_name'] ?? 'Unknown student'}',
                ),
                subtitle: Text(
                  '${zone?['name'] ?? 'Zone not set (prototype)'} · '
                  '${_elapsedLabel(alert['triggered_at'] as String)}',
                ),
                trailing: Chip(
                  label: Text(label.toUpperCase()),
                  labelStyle: TextStyle(fontSize: 9, color: color),
                  backgroundColor: color.withValues(alpha: 0.12),
                  visualDensity: VisualDensity.compact,
                ),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AlertDetailScreen(
                        alertId: alert['alert_id'] as String,
                        responderId: widget.responderId,
                      ),
                    ),
                  );
                  _refresh();
                },
              );
            },
          );
        },
      ),
    );
  }
}
