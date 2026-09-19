import 'package:app/features/auth/data/role_cache.dart';
import 'package:app/features/auth/domain/app_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RoleCache', () {
    test('returns null for a user that was never saved', () async {
      expect(await RoleCache.load('never-seen-user'), isNull);
    });

    test('round-trips a saved role for the right user', () async {
      await RoleCache.save('user-1', AppRole.student);
      expect(await RoleCache.load('user-1'), AppRole.student);
    });

    test('keeps different users independent', () async {
      await RoleCache.save('user-1', AppRole.student);
      await RoleCache.save('user-2', AppRole.responder);

      expect(await RoleCache.load('user-1'), AppRole.student);
      expect(await RoleCache.load('user-2'), AppRole.responder);
    });

    test('saving again for the same user overwrites the old role', () async {
      await RoleCache.save('user-1', AppRole.student);
      await RoleCache.save('user-1', AppRole.admin);

      expect(await RoleCache.load('user-1'), AppRole.admin);
    });
  });
}
