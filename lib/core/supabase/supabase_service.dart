import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around the Supabase client lifecycle.
///
/// Call [initialize] once in `main()` before `runApp`. After that,
/// [client] gives access to the shared [SupabaseClient] everywhere else.
class SupabaseService {
  SupabaseService._();

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.get('SUPABASE_URL'),
      publishableKey: dotenv.get('SUPABASE_ANON_KEY'),
      authOptions: const FlutterAuthClientOptions(),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
