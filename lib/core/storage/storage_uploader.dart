import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_service.dart';

/// Uploads images to Supabase Storage under `<bucket>/<userId>/<filename>`
/// — the path prefix matching auth.uid() is what the storage RLS policies
/// (supabase/migrations/0002_storage_buckets.sql) key off.
class StorageUploader {
  StorageUploader({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<String> uploadImage({
    required String bucket,
    required String userId,
    required File file,
    required String filename,
  }) async {
    final path = '$userId/$filename';
    await _client.storage
        .from(bucket)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    if (bucket == 'avatars') {
      // Public bucket — return the stable public URL.
      return _client.storage.from(bucket).getPublicUrl(path);
    }
    // Private bucket — a time-limited signed URL.
    return _client.storage.from(bucket).createSignedUrl(
          path,
          60 * 60 * 24 * 7, // 7 days
        );
  }
}
