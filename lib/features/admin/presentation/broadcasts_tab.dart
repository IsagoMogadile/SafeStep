import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../domain/admin_enums.dart';
import 'widgets/admin_async_error.dart';

/// scope.md §7 "Broadcast safety alerts": create, schedule, and retract
/// alerts (distinct from panic alerts). Target all campuses or specific
/// ones. Note: this is a hackathon prototype — a scheduled broadcast is
/// stored with `scheduled_at` set and `sent_at` left null; actually
/// flipping it to "sent" at that future time would need a server-side
/// cron/edge function, which is out of scope here. An immediate (no
/// future schedule) broadcast is marked sent right away.
class BroadcastsTab extends StatefulWidget {
  const BroadcastsTab({super.key, required this.adminId});

  final String adminId;

  @override
  State<BroadcastsTab> createState() => _BroadcastsTabState();
}

class _BroadcastsTabState extends State<BroadcastsTab> {
  final _repository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _broadcastsFuture;
  late Future<List<Map<String, dynamic>>> _campusesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _broadcastsFuture = _repository.fetchBroadcasts();
      _campusesFuture = _repository.fetchCampuses();
    });
  }

  Future<void> _openCreateBroadcast() async {
    final campuses = await _campusesFuture;
    if (!mounted) return;

    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String level = 'info';
    String? targetCampusId;
    DateTime? scheduledAt;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Broadcast a safety alert'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(labelText: 'Message'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: level,
                    decoration: const InputDecoration(labelText: 'Level'),
                    items: [
                      for (final v in broadcastLevelOptions)
                        DropdownMenuItem(value: v, child: Text(broadcastLevelLabel(v))),
                    ],
                    onChanged: (v) => setDialogState(() => level = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: targetCampusId,
                    decoration: const InputDecoration(labelText: 'Target campus'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All campuses')),
                      for (final c in campuses)
                        DropdownMenuItem(
                          value: c['campus_id'] as String,
                          child: Text(c['name'] as String),
                        ),
                    ],
                    onChanged: (v) => setDialogState(() => targetCampusId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          scheduledAt == null
                              ? 'Send immediately'
                              : 'Scheduled for ${scheduledAt.toString().substring(0, 16)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time == null) return;
                          setDialogState(() {
                            scheduledAt = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        },
                        child: const Text('Schedule'),
                      ),
                      if (scheduledAt != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setDialogState(() => scheduledAt = null),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    messageController.text.trim().isEmpty) {
                  return;
                }
                await _repository.createBroadcast(
                  adminId: widget.adminId,
                  title: titleController.text.trim(),
                  message: messageController.text.trim(),
                  level: level,
                  targetCampusId: targetCampusId,
                  scheduledAt: scheduledAt,
                );
                if (context.mounted) Navigator.of(context).pop(true);
              },
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );

    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _broadcastsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AdminAsyncError(error: snapshot.error!, onRetry: _refresh);
        }
        final broadcasts = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _openCreateBroadcast,
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('New broadcast'),
              ),
            ),
            const SizedBox(height: 16),
            if (broadcasts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No broadcasts yet.'),
              ),
            for (final b in broadcasts) _BroadcastCard(broadcast: b, onChanged: _refresh),
          ],
        );
      },
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({required this.broadcast, required this.onChanged});

  final Map<String, dynamic> broadcast;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final level = broadcast['level'] as String;
    final retracted = broadcast['retracted_at'] != null;
    final sent = broadcast['sent_at'] != null;
    final scheduled = broadcast['scheduled_at'] != null;
    final campusName = (broadcast['campuses'] as Map?)?['name'] as String?;

    String statusText;
    if (retracted) {
      statusText = 'Retracted';
    } else if (sent) {
      statusText = 'Sent';
    } else if (scheduled) {
      statusText = 'Scheduled for ${(broadcast['scheduled_at'] as String).substring(0, 16)}';
    } else {
      statusText = 'Draft';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: broadcastLevelColor(level).withValues(alpha: 0.15),
          child: Icon(Icons.campaign_outlined, color: broadcastLevelColor(level)),
        ),
        title: Text(broadcast['title'] as String),
        subtitle: Text(
          '${broadcast['message']}\n'
          '${broadcastLevelLabel(level)} · ${campusName ?? 'All campuses'} · $statusText',
        ),
        isThreeLine: true,
        trailing: (!retracted && sent)
            ? OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                onPressed: () async {
                  final repo = AdminRepository();
                  await repo.retractBroadcast(broadcast['broadcast_id'] as String);
                  onChanged();
                },
                child: const Text('Retract'),
              )
            : null,
      ),
    );
  }
}
