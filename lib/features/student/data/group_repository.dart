import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';

class GroupRepository {
  GroupRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> fetchGroup(String groupId) {
    return _client.from('walking_groups').select().eq('group_id', groupId).single();
  }

  Future<List<Map<String, dynamic>>> fetchMembers(String groupId) {
    return _client
        .from('group_members')
        .select('student_id, joined_at, students(full_name)')
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);
  }

  Future<bool> isMember(String groupId, String studentId) async {
    final row = await _client
        .from('group_members')
        .select('id')
        .eq('group_id', groupId)
        .eq('student_id', studentId)
        .maybeSingle();
    return row != null;
  }

  Future<void> join(String groupId, String studentId) async {
    await _client.from('group_members').insert({
      'group_id': groupId,
      'student_id': studentId,
    });
  }

  Future<void> leave(String groupId, String studentId) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('student_id', studentId);
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String groupId) {
    // supabase-flutter's .order() defaults to ascending: false (newest
    // first) — the opposite of SQL's ORDER BY default — so this must be
    // explicit or messages come back newest-first and, once fed through
    // the reversed ListView below, render newest-at-top instead of
    // newest-at-bottom.
    return _client
        .from('group_messages')
        .select('message_id, preset_key, created_at, student_id, students(full_name)')
        .eq('group_id', groupId)
        .order('created_at', ascending: true);
  }

  Future<void> sendPresetMessage({
    required String groupId,
    required String studentId,
    required String presetKey,
  }) async {
    await _client.from('group_messages').insert({
      'group_id': groupId,
      'student_id': studentId,
      'preset_key': presetKey,
    });
  }
}
