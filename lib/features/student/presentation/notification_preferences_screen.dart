import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKeys = {
  'safety_alerts': 'Safety alerts',
  'walk_with_me': 'Walk With Me reminders',
  'group_messages': 'Group messages',
  'report_updates': 'Report status updates',
};

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final _values = <String, bool>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _prefKeys.keys) {
      _values[key] = prefs.getBool('notif_$key') ?? true;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _values[key] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_$key', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Choose what SafeStep notifies you about. Emergency SOS '
                  'confirmations are always sent and cannot be turned off.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ..._prefKeys.entries.map(
                  (entry) => SwitchListTile(
                    title: Text(entry.value),
                    value: _values[entry.key] ?? true,
                    onChanged: (value) => _toggle(entry.key, value),
                  ),
                ),
              ],
            ),
    );
  }
}
