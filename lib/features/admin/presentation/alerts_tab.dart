import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/admin_repository.dart';
import '../domain/admin_enums.dart';
import 'admin_alert_detail_screen.dart';
import 'widgets/admin_async_error.dart';

String _formatTimestamp(String iso) =>
    DateFormat('d MMM yyyy, HH:mm').format(DateTime.parse(iso).toLocal());

/// Admin-wide alert visibility — every alert across every zone, not just
/// the ones a particular responder was notified about. Tapping a row
/// opens the full detail (scope.md §6 alert-detail fields, admin flavor).
class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  final _repository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() { _future = _repository.fetchAlerts(); });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AdminAsyncError(error: snapshot.error!, onRetry: _refresh);
        }
        final alerts = snapshot.data ?? [];
        final open = alerts.where((a) => openAlertStatuses.contains(a['status'])).toList();
        final closed = alerts.where((a) => !openAlertStatuses.contains(a['status'])).toList();

        if (alerts.isEmpty) {
          return const Center(child: Text('No alerts yet.'));
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (open.isNotEmpty) ...[
              Text('Active (${open.length})', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final a in open) _AlertRow(alert: a, onChanged: _refresh),
              const SizedBox(height: 20),
            ],
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final a in closed) _AlertRow(alert: a, onChanged: _refresh),
          ],
        );
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.onChanged});

  final Map<String, dynamic> alert;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final status = alert['status'] as String;
    final studentName = (alert['students'] as Map?)?['full_name'] as String? ?? 'Unknown';
    final zoneName = (alert['zones'] as Map?)?['name'] as String? ?? 'Unknown zone';
    final alertType = alert['alert_type'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: alertStatusColor(status).withValues(alpha: 0.15),
          child: Icon(
            alertType == 'silent' ? Icons.visibility_off_outlined : Icons.campaign_outlined,
            color: alertStatusColor(status),
          ),
        ),
        title: Text('$studentName · $zoneName'),
        subtitle: Text(
          '${alertType == 'silent'
              ? 'Silent alert'
              : alertType == 'walk_escalation'
              ? 'Walk With Me escalation'
              : 'Panic alert'} · ${_formatTimestamp(alert['triggered_at'] as String)}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: alertStatusColor(status).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            alertStatusLabel(status),
            style: TextStyle(
              color: alertStatusColor(status),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminAlertDetailScreen(alertId: alert['alert_id'] as String),
            ),
          );
          onChanged();
        },
      ),
    );
  }
}
