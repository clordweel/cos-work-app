import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 全应用共用的 [FlutterSecureStorage] 配置。
///
/// - Android：`resetOnError: false` 避免 Keystore/加密偏好偶发异常时**整表被清空**导致 sid 丢失。
/// - iOS：设备首次解锁后可读，减少冷启动读不到 Keychain 的概率。
final FlutterSecureStorage cosFlutterSecureStorage = FlutterSecureStorage(
  aOptions: _androidOptions,
  iOptions: _iosOptions,
);

const AndroidOptions _androidOptions = AndroidOptions(
  encryptedSharedPreferences: true,
  resetOnError: false,
);

const IOSOptions _iosOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);
