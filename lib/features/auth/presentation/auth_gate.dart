import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin/presentation/admin_home_shell.dart';
import '../../admin/presentation/admin_mobile_notice_screen.dart';
import '../../responder/presentation/responder_home_shell.dart';
import '../../student/presentation/student_home_shell.dart';
import '../data/auth_repository.dart';
import '../domain/app_role.dart';
import 'student_wizard_screen.dart';
import 'welcome_screen.dart';

/// Root of the auth-aware navigation: watches the Supabase session and
/// routes to the right top-level surface. Role is resolved by looking up
/// which table the signed-in user's row lives in (scope.md §2), never by a
/// separate app build.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authRepository = AuthRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authRepository.authStateChanges,
      builder: (context, snapshot) {
        final session = _authRepository.currentUser;
        if (session == null) {
          return const WelcomeScreen();
        }
        return _RoleResolver(
          key: ValueKey(session.id),
          userId: session.id,
          email: session.email ?? '',
          authRepository: _authRepository,
        );
      },
    );
  }
}

class _RoleResolver extends StatefulWidget {
  const _RoleResolver({
    super.key,
    required this.userId,
    required this.email,
    required this.authRepository,
  });

  final String userId;
  final String email;
  final AuthRepository authRepository;

  @override
  State<_RoleResolver> createState() => _RoleResolverState();
}

class _RoleResolverState extends State<_RoleResolver> {
  late final Future<AppRole?> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = widget.authRepository.resolveRole(
      widget.userId,
      email: widget.email,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppRole?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        switch (snapshot.data) {
          case AppRole.student:
            return const StudentHomeShell();
          case AppRole.responder:
            return const ResponderHomeShell();
          case AppRole.admin:
            // Admin is web-only (scope.md §2) — the same login screen and
            // role lookup apply everywhere, but an admin who opens the
            // mobile build gets a plain notice instead of a broken
            // desktop-shaped dashboard.
            return kIsWeb ? const AdminHomeShell() : const AdminMobileNoticeScreen();
          case null:
            // Signed up but never finished the student details wizard
            // (e.g. app was closed mid-flow) — resume it.
            return StudentWizardScreen(
              userId: widget.userId,
              email: widget.email,
            );
        }
      },
    );
  }
}
