import 'package:flutter/material.dart';

import '../../../core/widgets/listen_button.dart';

const _fullNoticeText =
    'This is a hackathon prototype. Every person, alert, and report in it '
    'is simulated demo data — no real students, no real emergencies. In an '
    'actual emergency, always contact official services directly. '
    'What we collect: your registration details, trusted contacts you add, '
    'your live or last-known location during an active alert or Safe Walks '
    'journey, any incident or Safe Ride reports you submit, and optional '
    'medical, vehicle, and mobility information. '
    'Three tiers of visibility. Restricted, emergency-only: your address, '
    'medical info, and vehicle or mobility details — never visible to '
    'admin, and visible to a responder only during your active alert. '
    'Aggregate-only: your date of birth, gender, and faculty or year, used '
    'only for anonymous pattern reporting. Operational: your name, campus, '
    'and alert or report history, visible to responders handling your '
    'alert and to admin for safety planning. '
    'Trusted contacts are notified with your location only when you send '
    'an alert or invite them to a Safe Walks journey, and can never remove '
    'themselves. '
    'Anonymous incident reports never attach your identity for admin or '
    'staff to see. '
    'In walking groups, fellow members see your name only, never your '
    'contact details or restricted information. '
    'Safe Ride reports are attributed to your account internally, but '
    'never shown publicly with your name attached. '
    'Alert and location data is kept only as long as needed for follow-up. '
    'You can edit or remove your medical, vehicle, and mobility info at '
    'any time, and permanently delete your account and all associated '
    'data from Settings — this cannot be undone. '
    'A real deployment of SafeStep would require university approval, '
    'formal security testing, legal review, and a written data-sharing '
    'agreement — none of that exists here; this prototype is a design '
    'concept, not a certified safety system.';

/// scope.md §8 "Privacy & POPIA": tiered data visibility (§5) explained
/// plainly, not just in the abstract — who specifically sees each kind
/// of information, and exactly when.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Notice'),
        actions: const [ListenButton(text: _fullNoticeText)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            margin: const EdgeInsets.only(bottom: 20),
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
                    'This is a hackathon prototype. Every person, alert, and '
                    'report in it is simulated demo data — no real students, '
                    'no real emergencies. In an actual emergency, always '
                    'contact official services directly.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const _Section(
            heading: 'What we collect',
            body:
                'Your registration details (name, contact number, campus, '
                'faculty & year, residence type, address), trusted contacts '
                'you add, your live or last-known location during an active '
                'alert or Safe Walks journey, any incident reports or Safe '
                'Ride reports you submit, and optional medical, vehicle, and '
                'mobility information you choose to provide.',
          ),
          _Section.rich(
            heading: 'Three tiers of visibility',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Not all of your information is treated the same way. '
                    'We use three tiers, and every screen that collects '
                    'sensitive data tells you which tier it falls into:',
                  ),
                ),
                _TierRow(
                  color: colorScheme.error,
                  title: 'Restricted — emergency-only',
                  body:
                      'Your residential address, medical info, and vehicle/'
                      'mobility details. Never visible to admin, never '
                      'browsable by anyone at any time. A responder can see '
                      'it only while you have an active alert — and it '
                      'disappears from their view again once the alert is '
                      'resolved.',
                ),
                _TierRow(
                  color: colorScheme.tertiary,
                  title: 'Aggregate-only',
                  body:
                      'Your date of birth, gender, and faculty/year. Used '
                      'only for anonymous pattern reporting (e.g. "reports '
                      'are higher near exam season") — never shown as a '
                      'browsable individual profile, even to admin.',
                ),
                _TierRow(
                  color: colorScheme.primary,
                  title: 'Operational',
                  body:
                      'Your name, campus, and alert/report history. Visible '
                      'to responders handling your alert and to admin for '
                      'safety planning and moderation.',
                ),
              ],
            ),
          ),
          const _Section(
            heading: 'Trusted contacts',
            body:
                'Contacts you add are notified with your location only when '
                'you send an alert or invite them to watch a Safe Walks '
                'journey. A contact can never remove themselves — only you '
                'can. If a contact\'s email matches an existing SafeStep '
                'account, they can accept live invites in-app; otherwise '
                'they\'re treated as SMS-only and never get app access to '
                'your data.',
          ),
          const _Section(
            heading: 'Anonymous incident reports',
            body:
                'If you submit a report anonymously, your identity is never '
                'attached to it for admin or staff to see — they see the '
                'report content only. Named reports show your identity so '
                'staff can follow up with you directly.',
          ),
          const _Section(
            heading: 'Walking groups',
            body:
                'Fellow group members can see your name only — never your '
                'contact details, address, or any restricted-tier '
                'information. Messages are limited to a fixed set of '
                'pre-approved phrases; there is no free-text or private '
                'messaging between members.',
          ),
          const _Section(
            heading: 'Safe Ride reports',
            body:
                'When you report a vehicle, the report is attributed to '
                'your account internally (so it can\'t be spoofed or used '
                'to impersonate an official record) but is never shown '
                'publicly with your name attached — other students only '
                'ever see the vehicle\'s resulting record.',
          ),
          const _Section(
            heading: 'Who can access what, overall',
            body:
                'Responders see only what\'s needed to respond to an alert '
                'in their assigned zone. Admin can manage zones, broadcasts, '
                'resources, and moderate reports and groups, but cannot '
                'browse individual student profiles beyond the operational '
                'tier above. Nobody outside SafeStep (no real police, no '
                'real university system) has any access in this prototype.',
          ),
          const _Section(
            heading: 'Retention & your rights',
            body:
                'Alert and location data is kept only as long as needed for '
                'follow-up. You can edit or remove your medical, vehicle, '
                'and mobility info at any time from your Profile. You can '
                'permanently delete your account and all associated data '
                '(trusted contacts, reports, alerts, group memberships) at '
                'any time from Settings — this cannot be undone.',
          ),
          const _Section(
            heading: 'A real deployment would need more',
            body:
                'A production version of SafeStep would require university '
                'approval, formal security testing, legal review, and a '
                'written data-sharing agreement between the university and '
                'any private security partner — none of that exists here. '
                'This prototype is a design concept, not a certified safety '
                'system.',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.heading, required this.body})
    : child = null;

  const _Section.rich({required this.heading, required Widget this.child})
    : body = null;

  final String heading;
  final String? body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (body != null) Text(body!, style: Theme.of(context).textTheme.bodyMedium),
          ?child,
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.color, required this.title, required this.body});

  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
