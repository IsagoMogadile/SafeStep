import 'package:flutter/material.dart';

/// Shown above a screen that's currently displaying a cached copy of
/// server data (map danger zones, the alerts feed) instead of a fresh
/// fetch — because browsing them is still more useful stale than not at
/// all, unlike a live safety check (Safe Ride, Safe Walks) which never
/// shows cached results. Never silently swaps in old data without
/// saying so.
class StalenessBanner extends StatelessWidget {
  const StalenessBanner({super.key, required this.lastUpdated});

  final DateTime? lastUpdated;

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 16, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lastUpdated == null
                  ? "You're offline — showing saved data that may be outdated."
                  : "You're offline — showing data from ${_relativeTime(lastUpdated!)}. "
                        'May be outdated.',
              style: TextStyle(fontSize: 11.5, color: colorScheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
