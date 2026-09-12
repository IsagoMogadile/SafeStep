import 'package:flutter/material.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'core/supabase/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await NotificationService.instance.init();
  runApp(const SafeStepApp());
}
