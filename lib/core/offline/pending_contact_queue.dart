import 'pending_sync_queue.dart';

/// A trusted contact added with no data connection. Editing/removing an
/// already-synced contact still requires a connection (see
/// `trusted_contacts_screen.dart`) — only a brand-new contact is simple
/// enough to safely queue, since there's no existing server row it could
/// conflict with.
class PendingContactQueue {
  PendingContactQueue._();

  static final _queue = PendingSyncQueue('pending_contacts_queue');

  static Future<void> add({
    required String studentId,
    required String name,
    required String relationship,
    String? email,
    String? phone,
    required DateTime createdAt,
  }) {
    return _queue.add({
      'local_id': createdAt.microsecondsSinceEpoch.toString(),
      'student_id': studentId,
      'name': name,
      'relationship': relationship,
      'email': email,
      'phone': phone,
      'created_at': createdAt.toUtc().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> loadAll() => _queue.loadAll();

  static Future<void> removeById(String localId) => _queue.removeById(localId);
}
