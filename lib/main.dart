import 'package:flutter/material.dart';

import 'app.dart';
import 'core/accessibility/font_scale_controller.dart';
import 'core/accessibility/tts_service.dart';
import 'core/connectivity/connectivity_controller.dart';
import 'core/l10n/app_locale_controller.dart';
import 'core/notifications/notification_service.dart';
import 'core/supabase/supabase_service.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await ConnectivityController.instance.init();
  await NotificationService.instance.init();
  await ThemeController.instance.load();
  await FontScaleController.instance.load();
  await TtsService.instance.load();
  await AppLocaleController.instance.load();
  runApp(const SafeStepApp());
}
