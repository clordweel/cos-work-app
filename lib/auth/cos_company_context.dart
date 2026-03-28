import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/cos_frappe_api_methods.dart';
import '../config/cos_site_store.dart';
import 'cos_secure_storage_factory.dart';
import 'cos_session_storage_keys.dart';
import 'cos_web_cookie_sync.dart';
import 'frappe_native_session.dart';

/// 单条公司（ERPNext `Company`）。
class CosCompanyRow {
  CosCompanyRow({required this.name, this.companyName});

  final String name;
  final String? companyName;

  String get displayLabel =>
      (companyName != null && companyName!.isNotEmpty) ? companyName! : name;
}

/// 同站点默认公司（User Default `company`）与可切换列表，数据来自 `cos.company_context_api`。
class CosCompanyContext extends ChangeNotifier {
  CosCompanyContext._();
  static final CosCompanyContext instance = CosCompanyContext._();

  final FlutterSecureStorage _secure = cosFlutterSecureStorage;

  bool loading = false;
  String? errorMessage;
  List<CosCompanyRow> companies = [];
  String? activeName;
  String? activeCompanyName;

  String? get activeDisplayLabel {
    if (activeCompanyName != null && activeCompanyName!.isNotEmpty) {
      return activeCompanyName;
    }
    if (activeName != null && activeName!.isNotEmpty) return activeName;
    return null;
  }

  void clear() {
    companies = [];
    activeName = null;
    activeCompanyName = null;
    errorMessage = null;
    loading = false;
    notifyListeners();
  }

  Future<List<Cookie>> _sessionCookies() async {
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

  /// 与 [CosAuthService._persistFrappeWebCookies] 同结构，供切换公司前合并 csrf 后写回。
  Future<void> _persistFrappeCookieSnapshot(List<Cookie> cookies) async {
    final prefs = await SharedPreferences.getInstance();
    final list = cookies
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

  /// 登录成功或冷启动恢复会话后调用，拉取列表与当前默认公司。
  Future<void> refreshFromServer() async {
    if (!CosSiteStore.instance.isInitialized) return;
    final sid = await _secure.read(key: CosSessionKeys.frappeSid);
    if (sid == null || sid.isEmpty) {
      clear();
      return;
    }

    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final origin = CosSiteStore.instance.origin;
      final cookies = await _sessionCookies();
      if (cookies.isEmpty) {
        errorMessage = '请先登录';
        loading = false;
        notifyListeners();
        return;
      }

      final listRes = await FrappeNativeSession.callMethodGet(
        siteOrigin: origin,
        cookies: cookies,
        dottedMethod: CosFrappeApiMethods.listAccessibleCompanies,
      );
      if (!listRes.ok) {
        if (!listRes.shouldInvalidateNativeSession) {
          errorMessage = listRes.errorText ?? '公司列表加载失败';
        }
        loading = false;
        notifyListeners();
        return;
      }

      final rows = <CosCompanyRow>[];
      final msg = listRes.message;
      if (msg is List) {
        for (final e in msg) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            final n = m['name']?.toString();
            if (n != null && n.isNotEmpty) {
              rows.add(CosCompanyRow(
                name: n,
                companyName: m['company_name']?.toString(),
              ));
            }
          }
        }
      }
      companies = rows;

      final curRes = await FrappeNativeSession.callMethodGet(
        siteOrigin: origin,
        cookies: cookies,
        dottedMethod: CosFrappeApiMethods.getSessionCompany,
      );
      if (curRes.ok && curRes.message is Map) {
        final m = Map<String, dynamic>.from(curRes.message as Map);
        final c = m['company']?.toString();
        activeName = (c != null && c.isNotEmpty) ? c : null;
        final cn = m['company_name']?.toString();
        activeCompanyName = (cn != null && cn.isNotEmpty) ? cn : null;
      } else {
        if (!curRes.ok && curRes.shouldInvalidateNativeSession) {
          loading = false;
          notifyListeners();
          return;
        }
        activeName = null;
        activeCompanyName = null;
      }
      loading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = '$e';
      loading = false;
      notifyListeners();
    }
  }

  /// 设置当前默认公司（会话级）。
  Future<String?> setActiveCompany(String name) async {
    if (!CosSiteStore.instance.isInitialized) return '请稍候再试';
    var cookies = await _sessionCookies();
    if (cookies.isEmpty) return '请先登录';

    loading = true;
    errorMessage = null;
    notifyListeners();

    final origin = CosSiteStore.instance.origin;
    // POST 依赖 X-Frappe-CSRF-Token；纯 login API 快照常无 csrf_token →「无效请求」
    try {
      final merged = await FrappeNativeSession.mergeCookiesFromDeskBootstrap(
        siteOrigin: origin,
        cookies: cookies,
      );
      await _persistFrappeCookieSnapshot(merged);
      await CosWebCookieSync.applyCookies(origin, merged);
      cookies = merged;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('setActiveCompany: 合并 Desk Cookie 失败 $e\n$st');
      }
    }

    final res = await FrappeNativeSession.callMethodPostForm(
      siteOrigin: origin,
      cookies: cookies,
      dottedMethod: CosFrappeApiMethods.setDefaultCompany,
      fields: {'company': name},
    );

    loading = false;
    if (!res.ok) {
      if (!res.shouldInvalidateNativeSession) {
        errorMessage = res.errorText;
      }
      notifyListeners();
      return res.shouldInvalidateNativeSession
          ? '登录已失效，请重新登录'
          : (res.errorText ?? '切换公司失败');
    }

    if (res.message is Map) {
      final m = Map<String, dynamic>.from(res.message as Map);
      activeName = m['company']?.toString();
      activeCompanyName = m['company_name']?.toString();
    }
    notifyListeners();
    return null;
  }
}
