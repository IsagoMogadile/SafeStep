import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/supabase/supabase_service.dart';

/// Safety broadcasts (admin-created, distinct from panic alerts — scope.md
/// §7/§9 `safety_broadcasts`). Reached via the header bell icon, not a
/// bottom tab (scope.md §5 "Bottom navigation").
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final Future<List<Map<String, dynamic>>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = SupabaseService.client
        .from('safety_broadcasts')
        .select()
        .not('sent_at', 'is', null)
        .filter('retracted_at', 'is', null)
        .order('sent_at', ascending: false);
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _alertsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final alerts = snapshot.data!;
          if (alerts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No safety alerts right now',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: alerts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final (color, icon) = _styleFor(alert['level'] as String?);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color, size: 18),
                ),
                title: Text(alert['title'] as String? ?? ''),
                subtitle: Text(alert['message'] as String? ?? ''),
                trailing: Chip(
                  label: Text((alert['level'] as String? ?? '').toUpperCase()),
                  labelStyle: TextStyle(fontSize: 10, color: color),
                  backgroundColor: color.withValues(alpha: 0.12),
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
