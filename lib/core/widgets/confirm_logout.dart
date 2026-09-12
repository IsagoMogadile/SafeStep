import 'package:flutter/material.dart';

/// Shared "Log out?" confirmation used everywhere a sign-out button
/// exists, so accidental taps don't immediately end the session.
Future<bool> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You can log back in anytime.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
