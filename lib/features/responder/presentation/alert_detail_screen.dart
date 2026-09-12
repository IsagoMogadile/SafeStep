import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/responder_repository.dart';
import 'write_report_screen.dart';

const _typeLabel = {
  'panic': 'Panic alert',
  'silent': 'Silent alert (unconfirmed)',
  'walk_escalation': 'Missed check-in',
};

/// scope.md §6 "Alert detail": student location + medical info banner
/// (only while active) + status actions.
class AlertDetailScreen extends StatefulWidget {
  const AlertDetailScreen({
    super.key,
    required this.alertId,
    required this.responderId,
  });

  final String alertId;
  final String responderId;

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  final _repository = ResponderRepository();
  late Future<Map<String, dynamic>> _alertFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _alertFuture = _fetchAlert();
  }

  Future<Map<String, dynamic>> _fetchAlert() {
    return SupabaseService.client
        .from('alerts')
        .select('*, students(full_name, medical_info), zones(name)')
        .eq('alert_id', widget.alertId)
        .single();
  }

  Future<void> _refresh() async {
    setState(() => _alertFuture = _fetchAlert());
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Detail')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _alertFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final alert = snapshot.data!;
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
                            '${zone?['name'] ?? 'Zone not set (prototype)'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(label: Text(status.replaceAll('_', ' ').toUpperCase())),
                  ],
                ),
                if (isActive && alert['alert_type'] == 'silent') ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.caution.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.caution.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          color: AppColors.caution,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Unconfirmed silent alert — the student may not be '
                            'able to speak or use their phone. Approach '
                            'discreetly; do not call out or announce a '
                            'response. Verify in person before treating this '
                            'as confirmed, and mark False Alarm – Verify if '
                            "there's no real emergency.",
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
                const SizedBox(height: 20),
                Text('Update status', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: (!isActive || _isBusy)
                          ? null
                          : () => _run(
                              () => _repository.acknowledge(
                                widget.alertId,
                                widget.responderId,
                              ),
                            ),
                      child: const Text('Acknowledge'),
                    ),
                    OutlinedButton(
                      onPressed: (!isActive || _isBusy)
                          ? null
                          : () => _run(() => _repository.dispatch(widget.alertId)),
                      child: const Text('Dispatched'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.safe),
                      onPressed: (!isActive || _isBusy)
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      WriteReportScreen(alertId: widget.alertId),
                                ),
                              );
                              _refresh();
                            },
                      child: const Text('Resolve'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.alert),
                      onPressed: (!isActive || _isBusy)
                          ? null
                          : () =>
                              _run(() => _repository.flagFalseAlarm(widget.alertId)),
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
