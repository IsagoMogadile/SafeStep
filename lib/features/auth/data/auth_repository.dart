import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/app_role.dart';

/// Result of checking whether a freshly-created auth account matches a
/// pending responder/admin invite (scope.md §4).
class InviteLinkResult {
  const InviteLinkResult({required this.role, required this.displayName});

  final AppRole role;
  final String displayName;
}

class AuthRepository {
  AuthRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Checks an email BEFORE creating anything, via a SECURITY DEFINER RPC
  /// callable while unauthenticated (supabase/migrations/0015). Fixes the
  /// "create account -> something went wrong -> user already exists" bug:
  /// the old flow called signUp() the moment email+password were entered,
  /// so abandoning the wizard left a real, permanent auth account with no
  /// completed profile, and a retry then failed with a confusing
  /// "already registered" error. Returns 'active' (a real account already
  /// exists — tell them to log in), 'invited' (a responder/admin invite
  /// is waiting — the existing single-screen self-activation is fine),
  /// or 'none' (safe to defer real account creation to the end of the
  /// student wizard).
  Future<String> checkEmailStatus(String email) async {
    final result = await _client.rpc('check_email_status', params: {'p_email': email});
    return result as String;
  }

  /// After a fresh signUp, checks whether this email matches a pending
  /// responder or admin invite row created ahead of time by an admin.
  /// If found, links it (`user_id` + `activation_status: 'active'`) and
  /// returns the resolved role. Returns null if no invite matched — the
  /// caller should then treat this as a brand-new student and continue to
  /// the details wizard.
  Future<InviteLinkResult?> claimPendingInvite({
    required String userId,
    required String email,
  }) async {
    final responderRow = await _client
        .from('responders')
        .update({'user_id': userId, 'activation_status': 'active'})
        .eq('email', email)
        .eq('activation_status', 'invited')
        .select('full_name')
        .maybeSingle();

    if (responderRow != null) {
      return InviteLinkResult(
        role: AppRole.responder,
        displayName: responderRow['full_name'] as String,
      );
    }

    final adminRow = await _client
        .from('admins')
        .update({'user_id': userId, 'activation_status': 'active'})
        .eq('email', email)
        .eq('activation_status', 'invited')
        .select('full_name')
        .maybeSingle();

    if (adminRow != null) {
      return InviteLinkResult(
        role: AppRole.admin,
        displayName: adminRow['full_name'] as String,
      );
    }

    return null;
  }

  /// For a returning login, figures out which table the user's row lives
  /// in so the app can route to the right post-login experience.
  ///
  /// Once a `students` row exists at all, a login always goes straight to
  /// Home — profile data is only ever collected during account creation,
  /// never re-demanded on a later login, even if some optional fields
  /// (trusted contacts, vehicle info) were skipped. The wizard's own
  /// resumability (student_wizard_screen.dart) handles the case of
  /// someone closing the app mid-signup, before this check ever runs.
  ///
  /// If nothing matches by user_id, this also tries [claimPendingInvite]
  /// before giving up — this is what makes login work for the seeded
  /// responder/admin accounts, whose auth.users row already existed
  /// *before* this app ever ran (created by the original seed script),
  /// so the normal signUp()-time claim in CreateAccountScreen never gets
  /// a chance to run for them: Supabase's signUp() on an email that
  /// already has an account returns a look-alike "success" response
  /// without creating a new session, so claimPendingInvite there runs
  /// unauthenticated and RLS correctly (silently) blocks it. A real,
  /// authenticated login is the reliable place to complete that link.
  Future<AppRole?> resolveRole(String userId, {String? email}) async {
    final student = await _client
        .from('students')
        .select('student_id')
        .eq('student_id', userId)
        .maybeSingle();
    if (student != null) return AppRole.student;

    final responder = await _client
        .from('responders')
        .select('responder_id')
        .eq('user_id', userId)
        .maybeSingle();
    if (responder != null) return AppRole.responder;

    final admin = await _client
        .from('admins')
        .select('admin_id')
        .eq('user_id', userId)
        .maybeSingle();
    if (admin != null) return AppRole.admin;

    if (email != null) {
      final invite = await claimPendingInvite(userId: userId, email: email);
      if (invite != null) return invite.role;
    }

    return null;
  }
}
