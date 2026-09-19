import 'package:app/core/offline/pending_alert_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PendingAlertQueue', () {
    test('add stores the fields SyncManager needs to replay the alert', () async {
      final triggeredAt = DateTime.utc(2026, 1, 1, 12, 30);
      await PendingAlertQueue.add(
        studentId: 'student-1',
        alertType: 'panic',
        lat: -33.98,
        lng: 25.66,
        triggeredAt: triggeredAt,
      );

      final items = await PendingAlertQueue.loadAll();
      expect(items, hasLength(1));
      final item = items.single;
      expect(item['student_id'], 'student-1');
      expect(item['alert_type'], 'panic');
      expect(item['lat'], -33.98);
      expect(item['lng'], 25.66);
      expect(item['triggered_at'], triggeredAt.toIso8601String());
      expect(item['local_id'], isNotNull);
    });

    test('works with no location captured', () async {
      await PendingAlertQueue.add(
        studentId: 'student-1',
        alertType: 'silent',
        triggeredAt: DateTime.now(),
      );

      final item = (await PendingAlertQueue.loadAll()).single;
      expect(item['lat'], isNull);
      expect(item['lng'], isNull);
    });

    test('removeById removes only the synced item, leaving others queued', () async {
      await PendingAlertQueue.add(
        studentId: 'a',
        alertType: 'panic',
        triggeredAt: DateTime(2026, 1, 1),
      );
      await PendingAlertQueue.add(
        studentId: 'b',
        alertType: 'silent',
        triggeredAt: DateTime(2026, 1, 2),
      );

      final firstLocalId = (await PendingAlertQueue.loadAll()).first['local_id'] as String;
      await PendingAlertQueue.removeById(firstLocalId);

      final remaining = await PendingAlertQueue.loadAll();
      expect(remaining, hasLength(1));
      expect(remaining.single['student_id'], 'b');
    });
  });
}
