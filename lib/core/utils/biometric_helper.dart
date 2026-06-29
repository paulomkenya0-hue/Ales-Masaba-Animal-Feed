import 'package:local_auth/local_auth.dart';

/// BiometricHelper - Hutumia alama ya kidole/uso kuthibitisha mtumiaji (ikiwa kifaa kinaweza)
class BiometricHelper {
  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Tumia alama ya kidole kuingia kwenye Ales Masaba Animal Feed',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
