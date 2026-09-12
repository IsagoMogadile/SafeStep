import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/responder_repository.dart';

/// scope.md §6 "History": past resolved/closed alerts.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.responderId});

  final String responderId;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _repository = ResponderRepository();
  late final Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _repository.fetchResolvedAlerts(widget.responderId);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return Center(
            child: Text(
              'No resolved alerts yet',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
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
              subtitle: Text(alert['responder_notes'] as String? ?? 'No notes'),
            );
          },
        );
      },
    );
  }
}
