import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/cos_frappe_cookie_snapshot.dart';
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

  /// 站点返回的宫格 + **未在后台出现的内置入口**（如壳内调试页），避免同步后只剩 bench 配置项。
  List<CosMiniProgram> get launcherPrograms {
    final remote = _remote;
    if (remote == null || remote.isEmpty) {
      return MiniProgramRegistry.forLauncherGrid;
    }
    final ids = {for (final p in remote) p.id};
    final extras = <CosMiniProgram>[];
    for (final p in MiniProgramRegistry.forLauncherGrid) {
      if (p.serverDocName == null && !ids.contains(p.id)) {
        extras.add(p);
      }
    }
    if (extras.isEmpty) return remote;
    return [...remote, ...extras];
  }

  CosMiniProgram? findById(String id) {
    if (_remote != null) {
      for (final p in _remote!) {
        if (p.id == id) return p;
      }
    }
    return MiniProgramRegistry.tryFindById(id);
  }

  /// 每次打开小程序前调用：独立 GET 单条 Desk 配置，不依赖宫格缓存、也不与进行中的宫格刷新合并。
  ///
  /// 若站点无对应 Doc 或无权读取，返回 [program] / [findById] 回退。
  Future<CosMiniProgram> resolveProgramForOpen(CosMiniProgram program) async {
    if (!CosSiteStore.instance.isInitialized) return program;
    final cookies = await _sessionCookies();
    if (cookies.isEmpty) return program;
    final origin = CosSiteStore.instance.origin;
    final res = await FrappeNativeSession.callMethodGet(
      siteOrigin: origin,
      cookies: cookies,
      dottedMethod: CosFrappeApiMethods.getMiniProgramLaunchConfig,
      queryParameters: {'program_id': program.id},
    );
    if (res.ok && res.message is Map) {
      final m = Map<String, dynamic>.from(res.message as Map);
      if (m.isNotEmpty) {
        return CosMiniProgram.fromLauncherPayload(m, origin);
      }
    }
    return findById(program.id) ?? program;
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

  /// POST 小程序自选前合并 Desk / 会话 CSRF，避免「无效请求」。
  Future<List<Cookie>> _sessionCookiesForPost() async {
    var c = await _sessionCookies();
    if (c.isEmpty) return c;
    final origin = CosSiteStore.instance.origin;
    try {
      c = await FrappeNativeSession.mergeCookiesFromDeskBootstrap(
        siteOrigin: origin,
        cookies: c,
      );
      c = await FrappeNativeSession.mergeCsrfFromShellTokenApi(
        siteOrigin: origin,
        cookies: c,
      );
    } catch (_) {}
    return c;
  }

  Future<void> _syncJarAfterMiniProgramPost(
    Uri origin,
    FrappeRpcResult res,
  ) async {
    if (res.mergedSessionCookies != null &&
        res.mergedSessionCookies!.isNotEmpty) {
      await persistFrappeCookieSnapshotAndSyncWebView(
        siteOrigin: origin,
        cookies: res.mergedSessionCookies!,
      );
    }
    try {
      var c = await _sessionCookies();
      if (c.isEmpty) return;
      c = await FrappeNativeSession.mergeCookiesFromDeskBootstrap(
        siteOrigin: origin,
        cookies: c,
      );
      c = await FrappeNativeSession.mergeCsrfFromShellTokenApi(
        siteOrigin: origin,
        cookies: c,
      );
      await persistFrappeCookieSnapshotAndSyncWebView(
        siteOrigin: origin,
        cookies: c,
      );
    } catch (_) {}
  }

  /// [force] 为 true 时：等待进行中的宫格请求结束后再发起新请求，避免打开小程序时复用到「尚未含最新 Desk 数据」的 in-flight Future。
  Future<void> refreshFromServer({bool force = false}) async {
    if (!CosSiteStore.instance.isInitialized) {
      return;
    }
    if (force) {
      while (_launcherRefreshInFlight != null) {
        try {
          await _launcherRefreshInFlight;
        } catch (_) {}
      }
    } else if (_launcherRefreshInFlight != null) {
      await _launcherRefreshInFlight!;
      return;
    }
    _launcherRefreshInFlight = _refreshFromServerImpl().whenComplete(() {
      _launcherRefreshInFlight = null;
    });
    await _launcherRefreshInFlight!;
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
    await _syncJarAfterMiniProgramPost(origin, res);
    await refreshFromServer();
    await refreshMarketFromServer();
    return null;
  }

  Future<String?> removeUserMiniProgram(String frappeDocName) async {
    final cookies = await _sessionCookiesForPost();
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
    await _syncJarAfterMiniProgramPost(origin, res);
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
