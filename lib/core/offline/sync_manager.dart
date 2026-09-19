import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/auth/data/trusted_contact_repository.dart';
import '../../features/student/data/alert_repository.dart';
import '../storage/storage_uploader.dart';
import '../supabase/supabase_service.dart';
import 'pending_alert_queue.dart';
import 'pending_contact_queue.dart';
import 'pending_report_queue.dart';

/// Replays everything queued while offline (see the `pending_*_queue.dart`
/// files) once a connection is available again — the "Pending Sync" →
/// "Synced" half of the offline pattern. Called on login and whenever
/// [ConnectivityController] flips from offline to online. Best-effort and
/// item-by-item: one item failing (still no real connection, a transient
/// error) leaves just that item queued for the next attempt rather than
/// blocking the rest.
class SyncManager {
  SyncManager._();

  static final instance = SyncManager._();

  final _alertRepository = AlertRepository();
  final _contactRepository = TrustedContactRepository();
  final _uploader = StorageUploader();

  bool _isSyncing = false;

  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _syncAlerts();
      await _syncReports();
      await _syncContacts();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncAlerts() async {
    for (final item in await PendingAlertQueue.loadAll()) {
      try {
        await _alertRepository.createAlert(
          studentId: item['student_id'] as String,
          alertType: item['alert_type'] as String,
          overrideLat: (item['lat'] as num?)?.toDouble(),
          overrideLng: (item['lng'] as num?)?.toDouble(),
          overrideTriggeredAtIso: item['triggered_at'] as String,
        );
        await PendingAlertQueue.removeById(item['local_id'] as String);
      } catch (e) {
        debugPrint('SyncManager: alert sync failed, will retry later — $e');
      }
    }
  }

  Future<void> _syncReports() async {
    for (final item in await PendingReportQueue.loadAll()) {
      try {
        String? photoUrl;
        final photoPath = item['photo_path'] as String?;
        if (photoPath != null && File(photoPath).existsSync()) {
          photoUrl = await _uploader.uploadImage(
            bucket: 'incident-photos',
            userId: item['student_id'] as String,
            file: File(photoPath),
            filename: 'report_${item['local_id']}.jpg',
          );
        }
        await SupabaseService.client.from('incident_reports').insert({
          'student_id': item['student_id'],
          'is_anonymous': item['anonymous'],
          'category': item['category'],
          'location_text': item['location_text'],
          'lat': item['lat'],
          'lng': item['lng'],
          'description': item['description'],
          'photo_url': photoUrl,
          'follow_up_requested': item['follow_up_requested'],
          'status': 'new',
        });
        await PendingReportQueue.removeById(item['local_id'] as String);
      } catch (e) {
        debugPrint('SyncManager: report sync failed, will retry later — $e');
      }
    }
  }

  Future<void> _syncContacts() async {
    for (final item in await PendingContactQueue.loadAll()) {
      try {
        await _contactRepository.addContact(
          studentId: item['student_id'] as String,
          name: item['name'] as String,
          relationship: item['relationship'] as String,
          email: item['email'] as String?,
          phone: item['phone'] as String?,
        );
        await PendingContactQueue.removeById(item['local_id'] as String);
      } catch (e) {
        debugPrint('SyncManager: contact sync failed, will retry later — $e');
      }
    }
  }
}
