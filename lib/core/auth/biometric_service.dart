import 'package:local_auth/local_auth.dart';

/// Thin wrapper around `local_auth`. `biometricOnly: false` lets it fall
/// back to the device's own PIN/pattern/password when biometrics aren't
/// enrolled, rather than failing outright on devices without a
/// fingerprint/face sensor set up.
class BiometricService {
  BiometricService._();

  static final _auth = LocalAuthentication();

  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate({
    String reason = 'Unlock SafeStep',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
