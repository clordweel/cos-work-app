import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// 系统生物识别（指纹 / 面容等），用于 App 解锁门禁。
///
/// FIDO2 / WebAuthn **Passkey** 需服务端作为 Relying Party 注册与校验；当前 Frappe 登录仍走账号密码，
/// 本类不实现跨设备 Passkey，仅调用系统 [LocalAuthentication]。
class CosBiometricGate {
  CosBiometricGate._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// 是否已录入至少一种系统生物特征（或可走生物识别流程）。
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
