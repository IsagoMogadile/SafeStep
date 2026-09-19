import 'pending_sync_queue.dart';

/// An incident report ("Report a Concern") submitted with no data
/// connection. The photo, if any, is kept as a local file path — the
/// file itself already lives in the OS's own picker cache/temp dir,
/// which is enough to survive until [SyncManager] uploads it — nothing
/// is written to `incident_reports` until then.
class PendingReportQueue {
  PendingReportQueue._();

  static final _queue = PendingSyncQueue('pending_reports_queue');

  static Future<void> add({
    required String studentId,
    required String category,
    required String locationText,
    double? lat,
    double? lng,
    required String description,
    required bool anonymous,
    required bool followUpRequested,
    String? photoPath,
    required DateTime createdAt,
  }) {
    return _queue.add({
      'local_id': createdAt.microsecondsSinceEpoch.toString(),
      'student_id': studentId,
      'category': category,
      'location_text': locationText,
      'lat': lat,
      'lng': lng,
      'description': description,
      'anonymous': anonymous,
      'follow_up_requested': followUpRequested,
      'photo_path': photoPath,
      'created_at': createdAt.toUtc().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> loadAll() => _queue.loadAll();

  static Future<void> removeById(String localId) => _queue.removeById(localId);
}
