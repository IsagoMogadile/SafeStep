import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_role.dart';

/// Remembers the last role [AuthRepository.resolveRole] actually
/// confirmed with the server for a given user, so a later login attempt
/// with no connection can still reach the right home shell instead of
/// being treated as an incomplete account — a network failure and "the
/// server confirmed no row exists" are different things, and only the
/// second one should ever route to [IncompleteAccountScreen].
class RoleCache {
  RoleCache._();

  static String _key(String userId) => 'last_known_role_$userId';

  static Future<void> save(String userId, AppRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), role.name);
  }

  static Future<AppRole?> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key(userId));
    if (saved == null) return null;
    for (final role in AppRole.values) {
      if (role.name == saved) return role;
    }
    return null;
  }
}
