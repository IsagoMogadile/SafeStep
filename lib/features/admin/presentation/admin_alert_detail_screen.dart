import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/admin_repository.dart';
import '../domain/admin_enums.dart';

const _typeLabel = {
  'panic': 'Panic alert',
  'silent': 'Silent alert (unconfirmed)',
  'walk_escalation': 'Missed check-in',
};

/// Admin's full-oversight view of a single alert (scope.md §6 fields,
/// admin flavor): student + zone + medical banner while active, plus the
/// full fan-out list of notified responders/trusted contacts and who
/// acknowledged — the same "Acknowledged by [name/org]" multi-responder
/// visibility a responder gets, but admin-wide across every zone.
class AdminAlertDetailScreen extends StatefulWidget {
  const AdminAlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  State<AdminAlertDetailScreen> createState() => _AdminAlertDetailScreenState();
}

class _AdminAlertDetailScreenState extends State<AdminAlertDetailScreen> {
  final _repository = AdminRepository();
  late Future<Map<String, dynamic>> _future;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchAlertDetail(widget.alertId);
  }

  Future<void> _refresh() async {
    setState(() { _future = _repository.fetchAlertDetail(widget.alertId); });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
      await _refresh();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _resolveWithNotes() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve alert'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _repository.resolveAlert(widget.alertId, notes: controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Detail')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }

          final alert = snapshot.data!['alert'] as Map<String, dynamic>;
          final recipients = snapshot.data!['recipients'] as List<Map<String, dynamic>>;
          final student = alert['students'] as Map<String, dynamic>?;
          final zone = alert['zones'] as Map<String, dynamic>?;
          final status = alert['status'] as String? ?? 'new';
          final medicalInfo = student?['medical_info'] as String?;
          final isActive = status != 'resolved' && status != 'false_alarm_verify';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student?['full_name'] as String? ?? 'Unknown student',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${_typeLabel[alert['alert_type']] ?? 'Alert'} · '
                            '${zone?['name'] ?? 'Zone not set'}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
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
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Triggered ${alert['triggered_at']}'
                  '${alert['resolved_at'] != null ? ' · Resolved ${alert['resolved_at']}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (isActive && alert['alert_type'] == 'silent') ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.caution.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.caution.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.visibility_off_outlined, color: AppColors.caution, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Unconfirmed silent alert — the student may not be able to '
                            'speak or use their phone. Verify in person before treating '
                            "this as confirmed, and mark False Alarm – Verify if there's "
                            'no real emergency.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isActive && medicalInfo != null && medicalInfo.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.alert.withValues(alpha: 0.08),
                      border: Border.all(color: AppColors.alert.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.medical_information_outlined, color: AppColors.alert, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Medical info available',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                              ),
                              Text(medicalInfo, style: const TextStyle(fontSize: 11.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (alert['responder_notes'] != null) ...[
                  const SizedBox(height: 14),
                  Text('Responder notes', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(alert['responder_notes'] as String),
                ],
                const SizedBox(height: 20),
                Text(
                  'Notified (${recipients.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final r in recipients) _RecipientRow(recipient: r),
                const SizedBox(height: 20),
                Text('Admin actions', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: (!isActive || _isBusy)
                          ? null
                          : () => _run(() => _repository.dispatchAlert(widget.alertId)),
                      child: const Text('Dispatched'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.safe),
                      onPressed: (!isActive || _isBusy) ? null : _resolveWithNotes,
                      child: const Text('Resolve'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.alert),
                      onPressed: (!isActive || _isBusy)
                          ? null
                          : () => _run(() => _repository.flagAlertFalseAlarm(widget.alertId)),
                      child: const Text('False Alarm – Verify'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({required this.recipient});

  final Map<String, dynamic> recipient;

  @override
  Widget build(BuildContext context) {
    final responder = recipient['responders'] as Map?;
    final contact = recipient['trusted_contacts'] as Map?;
    final acknowledged = recipient['acknowledged_at'] != null;
    final name = responder != null
        ? '${responder['full_name']} (${orgLabel(responder['organization'] as String)})'
        : (contact?['name'] as String? ?? 'Trusted contact');

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        responder != null ? Icons.shield_outlined : Icons.person_outline,
        size: 20,
        color: acknowledged ? AppColors.safe : Theme.of(context).colorScheme.outline,
      ),
      title: Text(name),
      trailing: Text(
        acknowledged ? 'Acknowledged' : 'Notified',
        style: TextStyle(
          fontSize: 12,
          color: acknowledged ? AppColors.safe : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
