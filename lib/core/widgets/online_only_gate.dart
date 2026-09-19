import 'package:flutter/material.dart';

import '../connectivity/connectivity_controller.dart';

/// Runs [action] if online; otherwise shows the standard "requires an
/// internet connection" dialog instead of silently doing nothing (or
/// letting a network call fail with a confusing error). Per spec: an
/// online-only feature stays visible and tappable, but explains itself
/// rather than pretending to work or disappearing.
Future<void> runIfOnline(
  BuildContext context, {
  required String featureName,
  required Future<void> Function() action,
}) async {
  if (ConnectivityController.instance.isOnline) {
    await action();
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.wifi_off_rounded),
      title: Text('$featureName requires an internet connection'),
      content: const Text(
        'This feature requires an internet connection. Please reconnect '
        'and try again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Visually dims an online-only entry point while offline, with a small
/// lock badge, so it's clearly (but not confusingly) unavailable rather
/// than looking identical to a working feature. Purely cosmetic — [child]
/// keeps receiving taps, so its own `onTap` (wrapped in [runIfOnline])
/// still shows the explanatory dialog. Automatically un-dims the instant
/// [ConnectivityController] reports a reconnect.
class OnlineOnlyDimmer extends StatelessWidget {
  const OnlineOnlyDimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityController.instance,
      builder: (context, isOnline, _) {
        if (isOnline) return child;
        return Stack(
          children: [
            Opacity(opacity: 0.45, child: child),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, size: 12, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
