import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-adjustable text scale, additive to the OS's own accessibility text
/// size and the app's small built-in readability boost (app.dart) rather
/// than replacing either. Persisted like ThemeController.
class FontScaleController extends ValueNotifier<double> {
  FontScaleController._() : super(1.0);

  static final instance = FontScaleController._();

  static const _key = 'font_scale';

  /// Named steps rather than a free slider — easier to reason about and
  /// to announce for screen-reader users.
  static const steps = {
    'Small': 0.9,
    'Default': 1.0,
    'Large': 1.15,
    'Extra Large': 1.3,
  };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getDouble(_key) ?? 1.0;
  }

  Future<void> setScale(double scale) async {
    value = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, scale);
  }
}
