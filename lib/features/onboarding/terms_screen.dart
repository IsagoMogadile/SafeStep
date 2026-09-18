import 'package:flutter/material.dart';

import '../../core/widgets/listen_button.dart';

/// Shown once, as the last step of onboarding, before a device is allowed
/// past the Welcome screen — required reading, not skippable, since it's
/// where the "this is a hackathon prototype, not a real emergency service"
/// disclaimer lives (docs/scope.md §13).
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        actions: [ListenButton(text: _allTermsText)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: colorScheme.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'SafeStep is a prototype. It does not replace calling '
                              'real emergency services. In a genuine emergency, '
                              'always contact official campus security or '
                              'emergency services directly.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._sections.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.$1,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.$2,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I have read and agree to the Terms & Conditions and '
                        'the Privacy Notice.',
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _agreed ? widget.onAccepted : null,
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String get _allTermsText => _sections.map((s) => '${s.$1}. ${s.$2}').join(' ');

const _sections = [
  (
    'What SafeStep is',
    'A campus safety companion app for NMU\'s Summerstrand campuses. This '
        'build is a prototype: every person, alert, and report in it is '
        'simulated data, used to demonstrate how the app would work.',
  ),
  (
    'Not a replacement for emergency services',
    'SOS, Safe Walks, and reporting features in this prototype are not '
        'connected to real police, ambulance, or official campus security '
        'dispatch systems. Never rely on this app in place of calling for '
        'real help.',
  ),
  (
    'Your data',
    'Real accounts, real Supabase infrastructure, and real device GPS are '
        'used to run the app, but no real personal or medical data should be '
        'entered. Data visibility follows the tiers described in the Privacy '
        'Notice: some fields are only ever visible to a responder during your '
        'own active alert, and some are aggregate-only.',
  ),
  (
    'Location & permissions',
    'Location, camera, contacts, and notification permissions are used only '
        'to power the features you actively use (SOS location, Safe Ride '
        'plate scanning, trusted-contact lookup, alert/journey '
        'notifications).',
  ),
  (
    'Account responsibility',
    'You are responsible for keeping your login credentials private. Trusted '
        'contacts you add are notified on your behalf when you trigger an '
        'alert or start a monitored walk.',
  ),
];
