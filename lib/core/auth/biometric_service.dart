import 'package:local_auth/local_auth.dart';

/// Thin wrapper around device lock capability.
///
/// `authenticate()` is deliberately a simulated check, not a real
/// `local_auth` biometric prompt — feedback: "I love it but it uses my
/// phone real data, make it a dummy, any fingerprint should be able to
/// open the app." This is a demo app-lock, not a real security boundary
/// (the session itself is already protected by real Supabase Auth), so
/// it never reads the device's actual enrolled fingerprint/face data —
/// any tap "succeeds" after a short simulated scan, so anyone can open
/// the demo regardless of whose biometrics are enrolled on the physical
/// phone.
class BiometricService {
  BiometricService._();

  static final _auth = LocalAuthentication();

  /// Still checks real device capability (has a lock screen / sensor at
  /// all) — this doesn't read any personal biometric data, just whether
  /// the hardware exists, so it's fine to keep real.
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
    await Future.delayed(const Duration(milliseconds: 900));
    return true;
  }
}
