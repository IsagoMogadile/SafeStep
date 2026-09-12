import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_service.dart';

/// scope.md §5 "Safety resources": seeded guidance + admin-verified
/// community-submitted tips, read from the real `resources` table.
class SafetyResourcesScreen extends StatefulWidget {
  const SafetyResourcesScreen({super.key});

  @override
  State<SafetyResourcesScreen> createState() => _SafetyResourcesScreenState();
}

class _SafetyResourcesScreenState extends State<SafetyResourcesScreen> {
  late final Future<List<Map<String, dynamic>>> _resourcesFuture;

  @override
  void initState() {
    super.initState();
    _resourcesFuture = SupabaseService.client
        .from('resources')
        .select()
        .eq('status', 'published')
        .order('created_at');
  }

  IconData _iconFor(String? type) {
    return switch (type) {
      'community_tip' => Icons.chat_bubble_outline,
      _ => Icons.menu_book_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Safety Resources')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _resourcesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final resources = snapshot.data!;
          if (resources.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No published resources yet. Check back soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: resources.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final resource = resources[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    _iconFor(resource['type'] as String?),
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                title: Text(resource['title'] as String? ?? ''),
                subtitle: Text(resource['category'] as String? ?? ''),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => _ResourceDetailSheet(resource: resource),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ResourceDetailSheet extends StatelessWidget {
  const _ResourceDetailSheet({required this.resource});

  final Map<String, dynamic> resource;

  /// Splits body text apart from any `Watch: <title> - <url>` reference
  /// lines, so links can render as tappable rows instead of plain text.
  (String body, List<(String label, String url)> links) _parse(String content) {
    final lines = content.split('\n');
    final bodyLines = <String>[];
    final links = <(String, String)>[];
    final watchPattern = RegExp(r'^Watch:\s*(.+?)\s*-\s*(https?://\S+)$');

    for (final line in lines) {
      final match = watchPattern.firstMatch(line.trim());
      if (match != null) {
        links.add((match.group(1)!, match.group(2)!));
      } else {
        bodyLines.add(line);
      }
    }
    return (bodyLines.join('\n').trim(), links);
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (body, links) = _parse(resource['content'] as String? ?? '');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resource['title'] as String? ?? '',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(body),
              if (links.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...links.map(
                  (link) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(
                        link.$1,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: const Text('YouTube'),
                      onTap: () => _openLink(context, link.$2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
