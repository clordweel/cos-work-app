import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_brand.dart';
import '../config/cos_frappe_api_methods.dart';
import '../config/cos_site_store.dart';
import 'cos_web_cookie_sync.dart';
import 'cos_biometric_gate.dart';
import 'cos_secure_storage_factory.dart';
import 'cos_session_storage_keys.dart';
import 'frappe_native_session.dart';
import 'frappe_session_cookie_jar.dart';
import 'cos_company_context.dart';
import '../mini_program/cos_mini_program_catalog.dart';

const _kSecureWorkerPortalToken = 'cos_worker_portal_wpt';
const _kPrefsUserId = 'cos_frappe_user_id';
const _kPrefsFullName = 'cos_frappe_full_name';
const _kPrefsBiometricGateEnabled = 'cos_biometric_gate_enabled';

/// 原生登录态：Frappe 登录接口 + `sid` 持久化 + WebView Cookie 同步。
///
/// **凭证（Android）**：`sid`、Worker Portal token 等经 [FlutterSecureStorage] 走系统密钥库；
/// Frappe Cookie 列表 JSON 存 [SharedPreferences]（供 HTTP 重建；会话仍以 `sid` 为准）。
class CosAuthService extends ChangeNotifier {
  CosAuthService._();
  static final CosAuthService instance = CosAuthService._();

  final FlutterSecureStorage _secure = cosFlutterSecureStorage;

  bool _bootstrapDone = false;
  bool _loggedIn = false;
  String? _userId;
  String? _fullName;
  String? _localDisplayName;
  String? _localPhone;
  bool _biometricGateEnabled = false;
  bool _sessionBiometricUnlocked = true;

  bool get isBootstrapDone => _bootstrapDone;
  bool get isLoggedIn => _loggedIn;
  String? get userId => _userId;
  String? get fullName => _fullName;
  String? get localDisplayName => _localDisplayName;
  String? get localPhone => _localPhone;

  /// 用户是否开启「冷启动生物识别解锁」（指纹 / 面容等，非 Web Passkey）。
  bool get biometricGateEnabled => _biometricGateEnabled;

  /// 已登录且开启生物识别、但本会话尚未通过系统验证时为 true，应展示解锁页。
  bool get needsBiometricUnlock =>
      _loggedIn && _biometricGateEnabled && !_sessionBiometricUnlocked;

  /// 仅单测：跳过登录门禁。
  @visibleForTesting
  void testingForceAuthenticated() {
    _bootstrapDone = true;
    _loggedIn = true;
    _sessionBiometricUnlocked = true;
    _userId ??= 'test_user';
    notifyListeners();
  }

  Future<void> bootstrap() async {
    await CosSiteStore.instance.init();
    await _loadBiometricGatePref();
    final sid = await _secure.read(key: CosSessionKeys.frappeSid);
    if (sid == null || sid.isEmpty) {
      await _loadProfilePrefs();
      await _refreshLocalProfileFields();
      _loggedIn = false;
      _sessionBiometricUnlocked = true;
      _bootstrapDone = true;
      notifyListeners();
      return;
    }
    final origin = CosSiteStore.instance.origin;
    final verify = await FrappeNativeSession.verifySessionDetailed(
      siteOrigin: origin,
      sidValue: sid,
    );
    if (verify == FrappeSessionVerifyResult.unauthenticated) {
      await _clearSessionData(clearSecureSid: true);
      _loggedIn = false;
      _sessionBiometricUnlocked = true;
      _bootstrapDone = true;
      notifyListeners();
      return;
    }
    if (verify == FrappeSessionVerifyResult.inconclusive && kDebugMode) {
      debugPrint('bootstrap: 未连通服务器，暂保留本地登录状态');
    }
    await _restoreWebCookiesAfterVerify(origin, sid);
    await _mergeDeskBootstrapCookiesIntoSession(origin);
    await _loadProfilePrefs();
    await _refreshLocalProfileFields();
    _loggedIn = true;
    _sessionBiometricUnlocked =
        !_biometricGateEnabled || !await CosBiometricGate.hasEnrolledBiometrics();
    _bootstrapDone = true;
    notifyListeners();
    await CosCompanyContext.instance.refreshFromServer();
    unawaited(CosMiniProgramCatalog.instance.refreshFromServer());
  }

  Future<String?> login({
    required String usr,
    required String pwd,
  }) async {
    final origin = CosSiteStore.instance.origin;
    final outcome = await FrappeNativeSession.login(
      siteOrigin: origin,
      usr: usr.trim(),
      pwd: pwd,
    );
    if (!outcome.ok) {
      return outcome.errorMessage ?? '登录失败';
    }
    final sid = outcome.sidValue;
    if (sid == null) return '登录未完成，请重试';
    await _secure.write(key: CosSessionKeys.frappeSid, value: sid);
    var sessionCookies = await FrappeNativeSession.mergeCookiesFromDeskBootstrap(
      siteOrigin: origin,
      cookies: outcome.cookies,
    );
    await _persistFrappeWebCookies(sessionCookies);
    await CosWebCookieSync.applyCookies(origin, sessionCookies);
    CosMiniProgramCatalog.instance.clear();
    final uid = await FrappeNativeSession.getLoggedUser(
      siteOrigin: origin,
      cookies: sessionCookies,
    );
    _userId = uid ?? usr.trim();
    _fullName = _extractFullName(outcome.rawJson) ?? _userId;
    await _persistProfilePrefs();
    await _refreshLocalProfileFields();
    _loggedIn = true;
    _sessionBiometricUnlocked = true;
    _bootstrapDone = true;
    notifyListeners();
    await CosCompanyContext.instance.refreshFromServer();
    await CosMiniProgramCatalog.instance.refreshFromServer();
    await CosMiniProgramCatalog.instance.refreshMarketFromServer();
    return null;
  }

  Future<void> _loadBiometricGatePref() async {
    final prefs = await SharedPreferences.getInstance();
    _biometricGateEnabled = prefs.getBool(_kPrefsBiometricGateEnabled) ?? false;
  }

  /// 开启或关闭冷启动生物识别门禁；开启时会先要求一次系统验证。
  Future<String?> setBiometricGateEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (!enabled) {
      await prefs.setBool(_kPrefsBiometricGateEnabled, false);
      _biometricGateEnabled = false;
      _sessionBiometricUnlocked = true;
      notifyListeners();
      return null;
    }
    if (!await CosBiometricGate.isDeviceSupported()) {
      return '本机不支持指纹或面容';
    }
    if (!await CosBiometricGate.hasEnrolledBiometrics()) {
      return '请先在系统设置中录入指纹或面容';
    }
    var ok = await CosBiometricGate.authenticate(
      localizedReason: '验证通过后即可开启指纹/面容解锁',
    );
    if (!ok) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      ok = await CosBiometricGate.authenticate(
        localizedReason: '请再次验证以开启指纹/面容解锁',
      );
    }
    if (!ok) {
      return '验证未通过，可稍后在「设置」中开启指纹/面容解锁';
    }
    await prefs.setBool(_kPrefsBiometricGateEnabled, true);
    _biometricGateEnabled = true;
    _sessionBiometricUnlocked = true;
    notifyListeners();
    return null;
  }

  /// 门禁页：系统生物识别通过后进入主界面。
  Future<bool> unlockWithBiometric() async {
    if (!_loggedIn || !_biometricGateEnabled) return true;
    final ok = await CosBiometricGate.authenticate(
      localizedReason: '请验证身份以继续使用 $kAppDisplayName',
    );
    if (!ok) return false;
    _sessionBiometricUnlocked = true;
    notifyListeners();
    return true;
  }

  String? _extractFullName(Map<String, dynamic>? map) {
    if (map == null) return null;
    final m = map['message'];
    if (m is Map) {
      final fn = m['full_name'];
      if (fn is String && fn.isNotEmpty) return fn;
    }
    return null;
  }

  Future<void> logout() async {
    final sid = await _secure.read(key: CosSessionKeys.frappeSid);
    final origin = CosSiteStore.instance.origin;
    // 先清本地并刷新 UI，避免远端 /api/method/logout 阻塞导致「已点登出却仍停在历史页」。
    await _clearSessionData(clearSecureSid: true);
    _loggedIn = false;
    _sessionBiometricUnlocked = true;
    notifyListeners();
    if (sid != null && sid.isNotEmpty) {
      unawaited(FrappeNativeSession.logout(siteOrigin: origin, sidValue: sid));
    }
  }

  /// 修改站点等场景：清除本地会话，需重新登录。
  Future<void> clearSessionExpectRelogin() async {
    await _clearSessionData(clearSecureSid: true);
    _loggedIn = false;
    _sessionBiometricUnlocked = true;
    notifyListeners();
  }

  Future<void> _clearSessionData({required bool clearSecureSid}) async {
    CosMiniProgramCatalog.instance.clear();
    if (clearSecureSid) {
      CosCompanyContext.instance.clear();
      await _secure.delete(key: CosSessionKeys.frappeSid);
      await _secure.delete(key: _kSecureWorkerPortalToken);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsUserId);
    await prefs.remove(_kPrefsFullName);
    await prefs.remove(CosSessionKeys.frappeWebCookiesJson);
    _userId = null;
    _fullName = null;
    _localDisplayName = null;
    _localPhone = null;
    await CosWebCookieSync.clearAll();
  }

  Future<void> _refreshLocalProfileFields() async {
    final p = await readLocalProfile();
    _localDisplayName = p.displayName;
    _localPhone = p.phone;
  }

  Future<void> _loadProfilePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_kPrefsUserId);
    _fullName = prefs.getString(_kPrefsFullName);
  }

  Future<void> _persistProfilePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_userId != null) {
      await prefs.setString(_kPrefsUserId, _userId!);
    }
    if (_fullName != null) {
      await prefs.setString(_kPrefsFullName, _fullName!);
    }
  }

  Future<void> updateLocalProfile({
    String? displayName,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (displayName != null) {
      if (displayName.isEmpty) {
        await prefs.remove(ProfileLocalKeys.displayName);
      } else {
        await prefs.setString(ProfileLocalKeys.displayName, displayName);
      }
    }
    if (phone != null) {
      if (phone.isEmpty) {
        await prefs.remove(ProfileLocalKeys.phone);
      } else {
        await prefs.setString(ProfileLocalKeys.phone, phone);
      }
    }
    await _refreshLocalProfileFields();
    notifyListeners();
  }

  Future<({String? displayName, String? phone})> readLocalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      displayName: prefs.getString(ProfileLocalKeys.displayName),
      phone: prefs.getString(ProfileLocalKeys.phone),
    );
  }

  /// Worker Portal 用的 `wpt.` token（无则 Portal 会走自带登录页）。
  Future<String?> readWorkerPortalToken() => _secure.read(key: _kSecureWorkerPortalToken);

  Future<List<Cookie>> _persistedSessionCookies() async {
    if (!CosSiteStore.instance.isInitialized) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CosSessionKeys.frappeWebCookiesJson);
    final sid = await _secure.read(key: CosSessionKeys.frappeSid);
    final host = CosSiteStore.instance.origin.host;
    return FrappeNativeSession.cookiesFromPersistedJson(
      frappeCookiesJson: raw,
      host: host,
      sidValue: sid,
    );
  }

  /// 使用当前 Frappe 会话（sid + Cookie 快照）向站点索取或刷新 Worker Portal `wpt.` token。
  ///
  /// 解决：冷启动仅恢复 sid、旧 wpt 过期、或从未成功写入 wpt 时，WebView 内 Portal 无法鉴权。
  ///
  /// 换发失败**不会**清本机 Frappe 会话（见 [FrappeNativeSession.callMethodGet] 的
  /// `invalidateSessionOnAuthFailure: false`），避免杀后台后偶发 Login required 误删 `sid`。
  Future<void> ensureWorkerPortalTokenFresh() async {
    if (!CosSiteStore.instance.isInitialized) return;
    if (!_loggedIn) return;
    final origin = CosSiteStore.instance.origin;
    final cookies = await _persistedSessionCookies();
    if (cookies.isEmpty) {
      if (kDebugMode) {
        debugPrint('ensureWorkerPortalTokenFresh: 无可用会话 Cookie，跳过');
      }
      return;
    }
    FrappeRpcResult? lastFail;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
      final res = await FrappeNativeSession.callMethodGet(
        siteOrigin: origin,
        cookies: cookies,
        dottedMethod: CosFrappeApiMethods.issueWorkerPortalTokenFromSession,
        invalidateSessionOnAuthFailure: false,
      );
      if (res.ok) {
        final msg = res.message;
        if (msg is Map) {
          final t = msg['token'];
          if (t is String && t.startsWith('wpt.')) {
            await _secure.write(key: _kSecureWorkerPortalToken, value: t);
          }
        }
        return;
      }
      lastFail = res;
    }
    if (lastFail != null &&
        lastFail.indicatesAuthFailure &&
        lastFail.httpStatus != 503) {
      // 换发失败且为登录/会话类错误：清本地 wpt，避免长期带无效 Bearer 触发服务端删缓存后仍反复脏请求。
      await _secure.delete(key: _kSecureWorkerPortalToken);
    }
    if (kDebugMode) {
      debugPrint(
        'ensureWorkerPortalTokenFresh: ${lastFail?.errorText ?? "unknown"}',
      );
    }
  }

  /// 打开任意 Frappe WebView 前调用：按上次登录快照重灌 Cookie，并对 [primePageUrl] 二次 setCookie，
  /// 减少首跳仍无 sid 的概率。
  Future<void> ensureWebViewCookiesBeforeBrowse({Uri? primePageUrl}) async {
    if (!_loggedIn) return;
    final origin = CosSiteStore.instance.origin;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CosSessionKeys.frappeWebCookiesJson);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        final cookies = list
            .map((e) => _cookieFromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (cookies.isNotEmpty) {
          await CosWebCookieSync.applyCookies(
            origin,
            cookies,
            primeRequestUrl: primePageUrl,
          );
          return;
        }
      } catch (e, st) {
        debugPrint('ensureWebViewCookies: 快照无效 $e\n$st');
      }
    }
    final sid = await _secure.read(key: CosSessionKeys.frappeSid);
    if (sid != null && sid.isNotEmpty) {
      await CosWebCookieSync.applySidOnlyForBrowse(
        origin,
        sid,
        primeRequestUrl: primePageUrl,
      );
    }
  }

  /// 合并 `/app` 下发的 Cookie（csrf 等），修复仅含 sid 的快照导致 POST/Desk 失败。
  Future<void> _mergeDeskBootstrapCookiesIntoSession(Uri origin) async {
    final cookies = await _persistedSessionCookies();
    if (cookies.isEmpty) return;
    final merged = await FrappeNativeSession.mergeCookiesFromDeskBootstrap(
      siteOrigin: origin,
      cookies: cookies,
    );
    await _persistFrappeWebCookies(merged);
    await CosWebCookieSync.applyCookies(origin, merged);
  }

  Future<void> _restoreWebCookiesAfterVerify(Uri origin, String sid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CosSessionKeys.frappeWebCookiesJson);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        final cookies = list
            .map((e) => _cookieFromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (cookies.isNotEmpty) {
          await CosWebCookieSync.applyCookies(origin, cookies);
          return;
        }
      } catch (e, st) {
        debugPrint('restoreWebCookies: 快照无效 $e\n$st');
        await prefs.remove(CosSessionKeys.frappeWebCookiesJson);
      }
    }
    await CosWebCookieSync.applySidOnly(origin, sid);
  }

  Future<void> _persistFrappeWebCookies(List<Cookie> cookies) async {
    final sid = await _secure.read(key: CosSessionKeys.frappeSid);
    final host = CosSiteStore.instance.origin.host;
    final prepared = FrappeSessionCookieJar.prepareCookiesForPersistence(
      cookies,
      host,
      sid,
    );
    final prefs = await SharedPreferences.getInstance();
    final list = prepared
        .map(
          (c) => <String, dynamic>{
            'name': c.name,
            'value': c.value,
            if (c.domain != null) 'domain': c.domain,
            if (c.path != null) 'path': c.path,
            'secure': c.secure,
            'httpOnly': c.httpOnly,
            if (c.sameSite != null) 'sameSite': c.sameSite!.name,
          },
        )
        .toList();
    await prefs.setString(CosSessionKeys.frappeWebCookiesJson, jsonEncode(list));
  }

  Cookie _cookieFromJson(Map<String, dynamic> m) {
    final c = Cookie(m['name']! as String, m['value']! as String);
    if (m['domain'] != null) c.domain = m['domain'] as String;
    if (m['path'] != null) c.path = m['path'] as String;
    if (m.containsKey('secure')) c.secure = m['secure'] as bool;
    if (m.containsKey('httpOnly')) c.httpOnly = m['httpOnly'] as bool;
    final ss = m['sameSite'] as String?;
    if (ss != null) {
      for (final v in SameSite.values) {
        if (v.name == ss) {
          c.sameSite = v;
          break;
        }
      }
    }
    return c;
  }
}

abstract final class ProfileLocalKeys {
  static const displayName = 'cos_profile_local_display_name';
  static const phone = 'cos_profile_local_phone';
}
