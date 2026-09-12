import 'package:flutter/material.dart';

/// scope.md §5 "QR emergency points": scanning pre-fills location for a
/// faster alert. Real camera/QR wiring is a follow-up task — this is the
/// placeholder shell matching docs/prototype.html.
class QrScanScreen extends StatelessWidget {
  const QrScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Point')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 70,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Point your camera at a campus emergency QR point to '
                'instantly pre-fill your location for a faster alert.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
