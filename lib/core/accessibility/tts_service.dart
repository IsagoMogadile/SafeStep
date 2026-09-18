import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the "Listen" (read-aloud) action appears on content-heavy
/// screens (Terms, Privacy Notice, Safety Resources), plus the actual
/// text-to-speech engine wrapper. A `ValueNotifier<bool>` for the toggle,
/// same persisted-preference pattern as ThemeController/FontScaleController.
class TtsService extends ValueNotifier<bool> {
  TtsService._() : super(false);

  static final instance = TtsService._();

  static const _key = 'tts_enabled';

  final _tts = FlutterTts();
  bool _speaking = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool(_key) ?? false;
    _tts.setCompletionHandler(() => _speaking = false);
  }

  Future<void> setEnabled(bool enabled) async {
    value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
    if (!enabled) await stop();
  }

  bool get isSpeaking => _speaking;

  Future<void> speak(String text) async {
    if (_speaking) await stop();
    _speaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    _speaking = false;
    await _tts.stop();
  }
}
