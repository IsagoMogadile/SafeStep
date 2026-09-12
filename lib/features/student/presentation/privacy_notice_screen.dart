import 'package:flutter/material.dart';

/// scope.md §8 "Privacy & POPIA": tiered data visibility explained plainly.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Notice')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Section(
            heading: 'What we collect',
            body:
                'Your location during an active alert or journey, trusted '
                'contact details, and any reports you submit.',
          ),
          const _Section(
            heading: 'Why',
            body:
                'To notify responders and your trusted contacts quickly '
                'during an emergency.',
          ),
          const _Section(
            heading: 'Who can access it',
            body:
                'Campus security only during an active alert, and admin for '
                'reports and safety planning.',
          ),
          const _Section(
            heading: 'Retention',
            body:
                'Alert and location data is kept only as long as needed for '
                'follow-up, per POPIA.',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This is a hackathon prototype. All data shown is '
                    'simulated. In an emergency, always contact official '
                    'services directly.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$heading: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }
}
