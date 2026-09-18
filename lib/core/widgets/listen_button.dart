import 'package:flutter/material.dart';

import '../accessibility/tts_service.dart';

/// A "Listen" action that reads [text] aloud via [TtsService], shown only
/// when the user has turned Text-to-Speech on in Settings > Accessibility.
class ListenButton extends StatelessWidget {
  const ListenButton({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TtsService.instance,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return IconButton(
          tooltip: 'Listen',
          icon: const Icon(Icons.volume_up_outlined),
          onPressed: () => TtsService.instance.speak(text),
        );
      },
    );
  }
}
