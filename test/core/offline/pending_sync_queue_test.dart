import 'package:app/core/offline/pending_sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PendingSyncQueue', () {
    test('starts empty', () async {
      final queue = PendingSyncQueue('test_queue');
      expect(await queue.loadAll(), isEmpty);
    });

    test('add appends an item and loadAll returns it', () async {
      final queue = PendingSyncQueue('test_queue');
      await queue.add({'local_id': '1', 'value': 'a'});
      await queue.add({'local_id': '2', 'value': 'b'});

      final items = await queue.loadAll();
      expect(items, hasLength(2));
      expect(items[0]['value'], 'a');
      expect(items[1]['value'], 'b');
    });

    test('removeById only removes the matching item', () async {
      final queue = PendingSyncQueue('test_queue');
      await queue.add({'local_id': '1', 'value': 'a'});
      await queue.add({'local_id': '2', 'value': 'b'});

      await queue.removeById('1');

      final items = await queue.loadAll();
      expect(items, hasLength(1));
      expect(items.single['local_id'], '2');
    });

    test('separate queue keys stay independent', () async {
      final queueA = PendingSyncQueue('queue_a');
      final queueB = PendingSyncQueue('queue_b');
      await queueA.add({'local_id': '1'});

      expect(await queueA.loadAll(), hasLength(1));
      expect(await queueB.loadAll(), isEmpty);
    });
  });
}
