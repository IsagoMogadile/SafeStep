import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/responder_repository.dart';

String _timestampLabel(String iso) =>
    DateFormat('d MMM yyyy, HH:mm').format(DateTime.parse(iso).toLocal());

/// scope.md §6 "History": past resolved/closed alerts.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.responderId});

  final String responderId;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _repository = ResponderRepository();
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _repository.fetchResolvedAlerts(widget.responderId);
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = _repository.fetchResolvedAlerts(widget.responderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SkeletonList();
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text(
                      'No resolved alerts yet',
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
              final alert = rows[index]['alerts'] as Map<String, dynamic>;
              final student = alert['students'] as Map<String, dynamic>?;
              final status = alert['status'] as String?;
              final isFalseAlarm = status == 'false_alarm_verify';
              final color = isFalseAlarm ? colorScheme.outline : AppColors.safe;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(Icons.check_outlined, color: color, size: 18),
                ),
                title: Text(
                  '${student?['full_name'] ?? 'Unknown student'} — '
                  '${isFalseAlarm ? 'False alarm' : 'Resolved'}',
                ),
                subtitle: Text(
                  'Triggered ${_timestampLabel(alert['triggered_at'] as String)}'
                  '${alert['resolved_at'] != null ? ' · Resolved ${_timestampLabel(alert['resolved_at'] as String)}' : ''}'
                  '\n${alert['responder_notes'] as String? ?? 'No notes'}',
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
