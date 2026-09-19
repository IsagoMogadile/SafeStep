import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/admin_repository.dart';
import 'widgets/admin_async_error.dart';

String _formatTimestamp(String iso) =>
    DateFormat('d MMM yyyy, HH:mm').format(DateTime.parse(iso).toLocal());

IconData _iconFor(String? targetType) {
  switch (targetType) {
    case 'zone':
      return Icons.location_on_outlined;
    case 'responder':
      return Icons.shield_outlined;
    case 'admin':
      return Icons.admin_panel_settings_outlined;
    case 'broadcast':
      return Icons.campaign_outlined;
    case 'resource':
      return Icons.menu_book_outlined;
    case 'incident_report':
      return Icons.report_outlined;
    case 'walking_group':
      return Icons.groups_outlined;
    case 'emergency_contact':
      return Icons.call_outlined;
    case 'vehicle_offense':
      return Icons.directions_car_outlined;
    case 'alert':
      return Icons.campaign_outlined;
    default:
      return Icons.history_outlined;
  }
}

/// A single browsable interface over the `audit_logs` table, populated by
/// [AdminRepository]'s `_logAction` calls on every mutating admin action
/// (zones, responders/admins, broadcasts, resources, incident reports,
/// walking groups, emergency contacts, Safe Ride report review, alerts).
/// Read-only by design — this is a trail of what happened, not something
/// an admin edits from here.
class AuditLogsTab extends StatefulWidget {
  const AuditLogsTab({super.key});

  @override
  State<AuditLogsTab> createState() => _AuditLogsTabState();
}

class _AuditLogsTabState extends State<AuditLogsTab> {
  final _repository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _future;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() { _future = _repository.fetchAuditLogs(); });

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> logs) {
    if (_query.trim().isEmpty) return logs;
    final q = _query.trim().toLowerCase();
    return logs.where((log) {
      final haystack = [
        log['admin_name'],
        log['action'],
        log['details'],
        log['target_type'],
      ].where((v) => v != null).join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

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
        final logs = _filtered(snapshot.data ?? []);

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Filter by admin, action, or target',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  (snapshot.data ?? []).isEmpty
                      ? 'No admin actions logged yet.'
                      : 'No log entries match "$_query".',
                ),
              ),
            for (final log in logs) _AuditLogRow(log: log),
          ],
        );
      },
    );
  }
}

class _AuditLogRow extends StatelessWidget {
  const _AuditLogRow({required this.log});

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final targetType = log['target_type'] as String?;
    final adminName = log['admin_name'] as String? ?? 'Unknown admin';
    final action = log['action'] as String? ?? '';
    final details = log['details'] as String? ?? action;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(_iconFor(targetType), color: colorScheme.onPrimaryContainer),
        ),
        title: Text(details),
        subtitle: Text(
          '$adminName · ${_formatTimestamp(log['created_at'] as String)}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            action,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
