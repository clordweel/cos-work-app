import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/frappe_native_session.dart';
import '../config/cos_frappe_api_methods.dart';
import '../config/cos_site_store.dart';
import '../auth/cos_secure_storage_factory.dart';
import '../auth/cos_session_storage_keys.dart';
import 'cos_market_program.dart';
import 'cos_mini_program.dart';
import '../routing/mini_program_registry.dart';

/// 从站点 [CosFrappeApiMethods.getLauncherPrograms] 拉取首页宫格；失败或无数据时回退 [MiniProgramRegistry.forLauncherGrid]。
class CosMiniProgramCatalog extends ChangeNotifier {
  CosMiniProgramCatalog._();
  static final CosMiniProgramCatalog instance = CosMiniProgramCatalog._();

  final FlutterSecureStorage _secure = cosFlutterSecureStorage;

  List<CosMiniProgram>? _remote;
  List<CosMarketProgram>? _market;
  bool loading = false;
  bool marketLoading = false;
  String? lastError;
  String? marketLastError;

  /// 合并并发刷新，避免两次请求乱序导致「先成功后失败」清空列表。
  Future<void>? _launcherRefreshInFlight;
  Future<void>? _marketRefreshInFlight;

  List<CosMiniProgram> get launcherPrograms =>
      (_remote != null && _remote!.isNotEmpty)
          ? _remote!
          : MiniProgramRegistry.forLauncherGrid;

  CosMiniProgram? findById(String id) {
    if (_remote != null) {
      for (final p in _remote!) {
        if (p.id == id) return p;
      }
    }
    return MiniProgramRegistry.tryFindById(id);
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

  Future<void> refreshFromServer() {
    if (!CosSiteStore.instance.isInitialized) {
      return Future<void>.value();
    }
    _launcherRefreshInFlight ??= _refreshFromServerImpl().whenComplete(() {
      _launcherRefreshInFlight = null;
    });
    return _launcherRefreshInFlight!;
  }

  Future<void> _refreshFromServerImpl() async {
    loading = true;
    lastError = null;
    notifyListeners();

    try {
      final cookies = await _sessionCookies();
      if (cookies.isEmpty) {
        loading = false;
        notifyListeners();
        return;
      }
      final origin = CosSiteStore.instance.origin;
      final res = await FrappeNativeSession.callMethodGet(
        siteOrigin: origin,
        cookies: cookies,
        dottedMethod: CosFrappeApiMethods.getLauncherPrograms,
      );
      if (!res.ok) {
        if (!res.shouldInvalidateNativeSession) {
          lastError = res.errorText;
        }
        loading = false;
        notifyListeners();
        return;
      }

      final msg = res.message;
      final out = <CosMiniProgram>[];
      if (msg is List) {
        for (final e in msg) {
          if (e is Map) {
            final p = CosMiniProgram.fromLauncherPayload(
              Map<String, dynamic>.from(e),
              origin,
            );
            out.add(p);
          }
        }
      }

      if (out.isEmpty) {
        _remote = null;
      } else {
        _remote = out;
      }
      lastError = null;
    } catch (e) {
      lastError = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  List<CosMarketProgram> get marketPrograms => _market ?? const [];

  /// 已成功拉取过市场列表（可能为空列表）。
  bool get marketLoaded => _market != null;

  Future<void> refreshMarketFromServer() {
    if (!CosSiteStore.instance.isInitialized) {
      return Future<void>.value();
    }
    _marketRefreshInFlight ??= _refreshMarketFromServerImpl().whenComplete(() {
      _marketRefreshInFlight = null;
    });
    return _marketRefreshInFlight!;
  }

  Future<void> _refreshMarketFromServerImpl() async {
    marketLoading = true;
    marketLastError = null;
    notifyListeners();

    try {
      final cookies = await _sessionCookies();
      if (cookies.isEmpty) {
        marketLoading = false;
        notifyListeners();
        return;
      }
      final origin = CosSiteStore.instance.origin;
      final res = await FrappeNativeSession.callMethodGet(
        siteOrigin: origin,
        cookies: cookies,
        dottedMethod: CosFrappeApiMethods.getMarketPrograms,
      );
      if (!res.ok) {
        if (!res.shouldInvalidateNativeSession) {
          marketLastError = res.errorText ?? '加载失败';
        }
        marketLoading = false;
        notifyListeners();
        return;
      }

      final msg = res.message;
      final out = <CosMarketProgram>[];
      if (msg is List) {
        for (final e in msg) {
          if (e is Map) {
            out.add(
              CosMarketProgram.fromPayload(
                Map<String, dynamic>.from(e),
                origin,
              ),
            );
          }
        }
      }
      _market = out;
      marketLastError = null;
    } catch (e) {
      marketLastError = '$e';
    } finally {
      marketLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addUserMiniProgram(String frappeDocName) async {
    final cookies = await _sessionCookies();
    if (cookies.isEmpty) return '未登录';
    final origin = CosSiteStore.instance.origin;
    final res = await FrappeNativeSession.callMethodPostForm(
      siteOrigin: origin,
      cookies: cookies,
      dottedMethod: CosFrappeApiMethods.addUserMiniProgram,
      fields: {'mini_program': frappeDocName},
    );
    if (!res.ok) {
      if (res.shouldInvalidateNativeSession) {
        return '登录已失效，请重新登录';
      }
      return res.errorText ?? '添加失败';
    }
    await refreshFromServer();
    await refreshMarketFromServer();
    return null;
  }

  Future<String?> removeUserMiniProgram(String frappeDocName) async {
    final cookies = await _sessionCookies();
    if (cookies.isEmpty) return '未登录';
    final origin = CosSiteStore.instance.origin;
    final res = await FrappeNativeSession.callMethodPostForm(
      siteOrigin: origin,
      cookies: cookies,
      dottedMethod: CosFrappeApiMethods.removeUserMiniProgram,
      fields: {'mini_program': frappeDocName},
    );
    if (!res.ok) {
      if (res.shouldInvalidateNativeSession) {
        return '登录已失效，请重新登录';
      }
      return res.errorText ?? '移除失败';
    }
    await refreshFromServer();
    await refreshMarketFromServer();
    return null;
  }

  void clear() {
    _remote = null;
    _market = null;
    lastError = null;
    marketLastError = null;
    loading = false;
    marketLoading = false;
    notifyListeners();
  }
}
