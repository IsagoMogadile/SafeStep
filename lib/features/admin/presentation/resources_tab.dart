import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../domain/admin_enums.dart';
import 'widgets/admin_async_error.dart';

/// scope.md §7 "Manage resources": create/edit guidance content; moderate
/// (approve/reject) community-submitted tips.
class ResourcesTab extends StatefulWidget {
  const ResourcesTab({super.key});

  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab> {
  final _repository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() { _future = _repository.fetchResources(); });

  Future<void> _openCreateResource() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final categoryController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add safety guidance'),
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
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category (e.g. Self-defense)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 5,
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
              if (titleController.text.trim().isEmpty) return;
              await _repository.createResource(
                title: titleController.text.trim(),
                content: contentController.text.trim(),
                category: categoryController.text.trim().isEmpty
                    ? null
                    : categoryController.text.trim(),
                type: 'guidance',
              );
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (created == true) _refresh();
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
        final resources = snapshot.data ?? [];
        final pending = resources.where((r) => r['status'] == 'pending_verification').toList();
        final published = resources.where((r) => r['status'] == 'published').toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _openCreateResource,
                icon: const Icon(Icons.add),
                label: const Text('Add guidance'),
              ),
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Pending community tips (${pending.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final r in pending) _ResourceCard(resource: r, onChanged: _refresh),
            ],
            const SizedBox(height: 20),
            Text('Published (${published.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final r in published) _ResourceCard(resource: r, onChanged: _refresh),
          ],
        );
      },
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource, required this.onChanged});

  final Map<String, dynamic> resource;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final status = resource['status'] as String;
    final isPending = status == 'pending_verification';
    final repo = AdminRepository();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: resourceStatusColor(status).withValues(alpha: 0.15),
          child: Icon(
            resource['type'] == 'community_tip' ? Icons.groups_2_outlined : Icons.menu_book_outlined,
            color: resourceStatusColor(status),
          ),
        ),
        title: Text(resource['title'] as String),
        subtitle: Text(
          '${resource['content'] ?? ''}\n'
          '${resourceTypeLabel(resource['type'] as String)} · '
          '${resource['category'] ?? 'Uncategorized'} · ${resourceStatusLabel(status)}',
        ),
        isThreeLine: true,
        trailing: isPending
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                    tooltip: 'Approve',
                    onPressed: () async {
                      await repo.approveResource(resource['resource_id'] as String);
                      onChanged();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    tooltip: 'Reject',
                    onPressed: () async {
                      await repo.rejectResource(resource['resource_id'] as String);
                      onChanged();
                    },
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
