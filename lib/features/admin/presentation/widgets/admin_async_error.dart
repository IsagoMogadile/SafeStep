import 'package:flutter/material.dart';

/// Every admin tab's FutureBuilder used to fall through to an empty-state
/// message on error (`snapshot.data ?? []`), which made a real query
/// failure look identical to "no rows yet" — indistinguishable from a
/// genuinely empty table. This surfaces the actual exception instead.
class AdminAsyncError extends StatelessWidget {
  const AdminAsyncError({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text("Couldn't load this data."),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
