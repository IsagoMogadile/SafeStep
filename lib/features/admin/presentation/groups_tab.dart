import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../domain/admin_enums.dart';
import 'widgets/admin_async_error.dart';

/// scope.md §7 "Walking groups": approve/reject every submitted group.
class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  final _repository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() { _future = _repository.fetchGroups(); });

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
        final groups = snapshot.data ?? [];
        final pending = groups.where((g) => g['status'] == 'pending').toList();
        final others = groups.where((g) => g['status'] != 'pending').toList();

        if (groups.isEmpty) {
          return const Center(child: Text('No walking groups yet.'));
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (pending.isNotEmpty) ...[
              Text(
                'Awaiting approval (${pending.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final g in pending) _GroupCard(group: g, onChanged: _refresh),
              const SizedBox(height: 20),
            ],
            Text('All groups', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final g in others) _GroupCard(group: g, onChanged: _refresh),
          ],
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onChanged});

  final Map<String, dynamic> group;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final status = group['status'] as String;
    final creator = (group['students'] as Map?)?['full_name'] as String?;
    final repo = AdminRepository();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group['name'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: groupStatusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    groupStatusLabel(status),
                    style: TextStyle(
                      color: groupStatusColor(status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Created by ${creator ?? 'Unknown'}'),
            if ((group['description'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(group['description'] as String),
            ],
            const SizedBox(height: 4),
            Text(
              '${group['route'] ?? 'No route set'} · ${group['meeting_time'] ?? '—'}'
              '${(group['requested_patrol'] as bool? ?? false) ? ' · Patrol requested' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton(
                    onPressed: () async {
                      await repo.setGroupStatus(group['group_id'] as String, 'approved');
                      onChanged();
                    },
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () async {
                      await repo.setGroupStatus(group['group_id'] as String, 'rejected');
                      onChanged();
                    },
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
