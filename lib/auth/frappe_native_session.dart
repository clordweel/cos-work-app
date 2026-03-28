import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/cos_frappe_api_methods.dart';
import 'cos_auth_service.dart';

/// 冷启动校验 sid 时的结论（避免把「网络抖动」当成「已登出」并清空本地会话）。
enum FrappeSessionVerifyResult {
  /// `get_logged_user` 返回有效用户
  authenticated,

  /// 明确 Guest、鉴权异常等，应清除本地 sid
  unauthenticated,

  /// 超时、网络错误、非 200 且无把握解析 — 保留本地 sid，照常进壳（含生物识别门禁）
  inconclusive,
}

/// Frappe `/api/method/*` 调用结果（已解析 `message`）。
class FrappeRpcResult {
  FrappeRpcResult._({
    required this.ok,
    this.message,
    this.errorText,
    this.httpStatus,
    this.excType,
    this.mergedSessionCookies,
  });

  factory FrappeRpcResult.success(
    dynamic message, {
    int? httpStatus,
    List<Cookie>? mergedSessionCookies,
  }) =>
      FrappeRpcResult._(
        ok: true,
        message: message,
        httpStatus: httpStatus,
        mergedSessionCookies: mergedSessionCookies,
      );

  factory FrappeRpcResult.failure(
    String text, {
    int? httpStatus,
    String? excType,
  }) =>
      FrappeRpcResult._(
        ok: false,
        errorText: text,
        httpStatus: httpStatus,
        excType: excType,
        mergedSessionCookies: null,
      );

  final bool ok;
  final dynamic message;
  final String? errorText;

  /// 响应对应的 HTTP 状态码（若有）；成功时多为 200。
  final int? httpStatus;

  /// Frappe JSON 中的 `exc_type`（若有）。
  final String? excType;

  /// 仅 [callMethodPostForm] 成功且响应含 `Set-Cookie` 时：请求 Cookie 与响应合并后的建议快照。
  final List<Cookie>? mergedSessionCookies;

  /// 是否应视为「会话已失效」并清本地登录态（如 User Not Found、AuthenticationError）。
  bool get indicatesAuthFailure {
    if (ok) return false;
    final s = httpStatus;
    if (s == 401) return true;
    final et = (excType ?? '').toLowerCase();
    if (et.contains('authentication')) return true;
    final t = (errorText ?? '').toLowerCase();
    if (t.contains('user not found')) return true;
    if (t.contains('usernotfounderror')) return true;
    if (t.contains('user none not found')) return true;
    if (t.contains('login required')) return true;
    if (t.contains('invalid session')) return true;
    if (t.contains('session expired')) return true;
    if (t.contains('does not exist') && t.contains('user')) return true;
    if (t.contains('doesnotexist') && t.contains('user')) return true;
    return false;
  }

  /// 是否应**清空本机 Frappe 会话**（sid / Cookie / Portal token）。
  ///
  /// 与 [indicatesAuthFailure] 区分：业务 **Permission / Validation / 单据不存在** 不代表已登出，
  /// 误清会导致「网络抖动或权限接口报错 → 整站被踢下线」。
  bool get shouldInvalidateNativeSession {
    if (ok) return false;
    final s = httpStatus;
    if (s == 401) return true;
    final et = (excType ?? '').toLowerCase();
    if (et.contains('permission')) return false;
    if (et.contains('validation')) return false;
    if (et.contains('doesnotexist')) return false;
    if (et.contains('linkvalidation')) return false;
    if (et.contains('dataerror')) return false;
    if (et.contains('authentication')) return true;
    if (et.contains('session') &&
        (et.contains('expir') || et.contains('stopped'))) {
      return true;
    }
    final t = (errorText ?? '').toLowerCase();
    if (t.contains('login required')) return true;
    if (t.contains('invalid session')) return true;
    if (t.contains('session expired')) return true;
    if (t.contains('user not found')) return true;
    if (t.contains('usernotfounderror')) return true;
    return false;
  }
}

/// 使用 [HttpClient] 调用 Frappe 登录/会话接口（不经过 WebView）。
abstract final class FrappeNativeSession {
  static HttpClient _newHttpClient() {
    final c = HttpClient();
    c.findProxy = HttpClient.findProxyFromEnvironment;
    return c;
  }

  /// 合并响应中的 Cookie：须让 [HttpClientResponse.cookies]（含 Secure/SameSite 等）优先，
  /// 仅用 `Set-Cookie` 头解析补 **HttpClient 未收录** 的键（如部分环境下缺失的 `sid`）。
  /// 若反客为主用简化的 name=value 覆盖，会抹掉 Secure，HTTPS WebView 可能不带会话 Cookie → Desk/接口全挂。
  static List<Cookie> _collectCookies(HttpClientResponse res, String host) {
    final byName = <String, Cookie>{};
    res.headers.forEach((name, values) {
      if (name.toLowerCase() != 'set-cookie') return;
      for (final line in values) {
        final parsed = _parseSetCookieNameValue(line, host);
        if (parsed != null) {
          byName.putIfAbsent(parsed.name, () => parsed);
        }
      }
    });
    for (final c in res.cookies) {
      byName[c.name] = c;
    }
    return byName.values.toList();
  }

  /// 只解析 `name=value` 段（分号前），供会话 Cookie 使用。
  static Cookie? _parseSetCookieNameValue(String line, String host) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    final sc = trimmed.indexOf(';');
    final nv = sc >= 0 ? trimmed.substring(0, sc).trim() : trimmed;
    final eq = nv.indexOf('=');
    if (eq <= 0) return null;
    final name = nv.substring(0, eq).trim();
    final value = nv.substring(eq + 1).trim();
    if (name.isEmpty) return null;
    return Cookie(name, value)
      ..domain = host
      ..path = '/';
  }

  static Future<FrappeLoginOutcome> login({
    required Uri siteOrigin,
    required String usr,
    required String pwd,
  }) async {
    final uri = CosFrappeApiMethods.uri(siteOrigin, CosFrappeApiMethods.login);
    final client = _newHttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      req.write(jsonEncode({'usr': usr, 'pwd': pwd}));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      Map<String, dynamic>? map;
      try {
        final d = jsonDecode(text);
        if (d is Map<String, dynamic>) map = d;
      } catch (_) {}

      if (res.statusCode >= 400) {
        return FrappeLoginOutcome.fail(_formatError(map, text));
      }
      if (map != null && map['exc_type'] != null) {
        return FrappeLoginOutcome.fail(_formatError(map, text));
      }

      final cookies = _collectCookies(res, siteOrigin.host);
      final hasSid = cookies.any((c) => c.name == 'sid');
      if (!hasSid) {
        if (kDebugMode) {
          debugPrint(
            'login: 响应无 sid；cookies=${cookies.map((c) => c.name).join(",")} '
            'status=${res.statusCode}',
          );
        }
        return FrappeLoginOutcome.fail('无法完成登录，请检查服务器地址与网络。');
      }
      return FrappeLoginOutcome.ok(cookies: cookies, rawJson: map);
    } on SocketException catch (e) {
      return FrappeLoginOutcome.fail('网络错误：${e.message}');
    } on HandshakeException catch (e) {
      return FrappeLoginOutcome.fail('TLS 握手失败：${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  static Future<String?> getLoggedUser({
    required Uri siteOrigin,
    required List<Cookie> cookies,
  }) async {
    final uri =
        CosFrappeApiMethods.uri(siteOrigin, CosFrappeApiMethods.getLoggedUser);
    final client = _newHttpClient();
    try {
      final req = await client.getUrl(uri);
      _attachCookies(req, siteOrigin.host, cookies);
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) return null;
      final map = jsonDecode(text);
      if (map is Map && map['message'] != null) {
        final m = map['message'].toString();
        if (m.isEmpty || m == 'Guest') return null;
        return m;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static const Duration _sessionVerifyTimeout = Duration(seconds: 12);
  static const int _sessionVerifyMaxAttempts = 3;
  static const Duration _sessionVerifyRetryDelay = Duration(milliseconds: 400);

  /// `get_logged_user` 返回的 `exc_type` 是否表示**会话已死**（勿把业务 Permission 当成登出）。
  static bool _verifyGetLoggedUserExcTypeMeansSessionDead(String excType) {
    final et = excType.toLowerCase();
    if (et.contains('permission')) return false;
    if (et.contains('validation')) return false;
    if (et.contains('doesnotexist')) return false;
    if (et.contains('linkvalidation')) return false;
    if (et.contains('dataerror')) return false;
    if (et.contains('authentication')) return true;
    if (et.contains('sessionstopped')) return true;
    if (et.contains('sessionexpired')) return true;
    return false;
  }

  static Future<FrappeSessionVerifyResult> _verifySessionDetailedOnce({
    required Uri siteOrigin,
    required String sidValue,
  }) async {
    final uri =
        CosFrappeApiMethods.uri(siteOrigin, CosFrappeApiMethods.getLoggedUser);
    final client = _newHttpClient();
    try {
      final req = await client.getUrl(uri);
      _attachCookies(req, siteOrigin.host, [
        Cookie('sid', sidValue)..domain = siteOrigin.host..path = '/',
      ]);
      final res = await req.close().timeout(_sessionVerifyTimeout);
      final text = await res
          .transform(utf8.decoder)
          .join()
          .timeout(_sessionVerifyTimeout);

      if (res.statusCode == 401) {
        return FrappeSessionVerifyResult.unauthenticated;
      }
      if (res.statusCode != 200) {
        return FrappeSessionVerifyResult.inconclusive;
      }

      Map<String, dynamic>? map;
      try {
        final d = jsonDecode(text);
        if (d is Map<String, dynamic>) map = d;
      } catch (_) {
        return FrappeSessionVerifyResult.inconclusive;
      }

      final excRaw = map?['exc_type']?.toString();
      if (excRaw != null && excRaw.isNotEmpty) {
        if (_verifyGetLoggedUserExcTypeMeansSessionDead(excRaw)) {
          return FrappeSessionVerifyResult.unauthenticated;
        }
        return FrappeSessionVerifyResult.inconclusive;
      }

      final msg = map?['message'];
      if (msg != null) {
        final m = msg.toString();
        if (m.isEmpty || m == 'Guest') {
          return FrappeSessionVerifyResult.unauthenticated;
        }
        return FrappeSessionVerifyResult.authenticated;
      }

      return FrappeSessionVerifyResult.inconclusive;
    } on TimeoutException {
      return FrappeSessionVerifyResult.inconclusive;
    } on SocketException {
      return FrappeSessionVerifyResult.inconclusive;
    } on HandshakeException {
      return FrappeSessionVerifyResult.inconclusive;
    } catch (_) {
      return FrappeSessionVerifyResult.inconclusive;
    } finally {
      client.close(force: true);
    }
  }

  /// 与 [verifySession] 相同入参，但区分「真失效」与「无法连接服务器」。
  ///
  /// 冷启动偶发 Guest/鉴权异常时最多重试 [_sessionVerifyMaxAttempts] 次，避免误清 [sid]。
  static Future<FrappeSessionVerifyResult> verifySessionDetailed({
    required Uri siteOrigin,
    required String sidValue,
  }) async {
    FrappeSessionVerifyResult last = FrappeSessionVerifyResult.unauthenticated;
    for (var attempt = 0; attempt < _sessionVerifyMaxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_sessionVerifyRetryDelay);
      }
      last = await _verifySessionDetailedOnce(
        siteOrigin: siteOrigin,
        sidValue: sidValue,
      );
      if (last == FrappeSessionVerifyResult.authenticated ||
          last == FrappeSessionVerifyResult.inconclusive) {
        return last;
      }
    }
    return last;
  }

  static Future<bool> verifySession({
    required Uri siteOrigin,
    required String sidValue,
  }) async {
    final r = await verifySessionDetailed(
      siteOrigin: siteOrigin,
      sidValue: sidValue,
    );
    return r == FrappeSessionVerifyResult.authenticated;
  }

  /// `POST cos.worker_portal_api.login_for_token`，返回 `wpt.` 前缀 token（与 Portal 前端一致）。
  static Future<WorkerPortalTokenOutcome> loginForWorkerPortalToken({
    required Uri siteOrigin,
    required String usr,
    required String pwd,
  }) async {
    final uri = CosFrappeApiMethods.uri(
      siteOrigin,
      CosFrappeApiMethods.workerPortalLoginForToken,
    );
    final client = _newHttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      req.write(jsonEncode({'usr': usr.trim(), 'pwd': pwd}));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      Map<String, dynamic>? map;
      try {
        final d = jsonDecode(text);
        if (d is Map<String, dynamic>) map = d;
      } catch (_) {}

      if (res.statusCode >= 400) {
        return WorkerPortalTokenOutcome.fail(_formatError(map, text));
      }
      if (map != null && map['exc_type'] != null) {
        return WorkerPortalTokenOutcome.fail(_formatError(map, text));
      }
      final msg = map?['message'];
      if (msg is Map) {
        final t = msg['token'];
        if (t is String && t.isNotEmpty) {
          return WorkerPortalTokenOutcome.ok(t);
        }
      }
      return WorkerPortalTokenOutcome.fail('未返回 Worker Portal token');
    } on SocketException catch (e) {
      return WorkerPortalTokenOutcome.fail('网络错误：${e.message}');
    } on HandshakeException catch (e) {
      return WorkerPortalTokenOutcome.fail('TLS 握手失败：${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  /// 从 Desk `/app` HTML 中兜底提取 `csrf_token`（部分环境仅写在页面而不 Set-Cookie）。
  static String? _tryParseCsrfFromDeskHtml(String html) {
    final m1 = RegExp(
      r'''csrf_token['"]\s*:\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    ).firstMatch(html);
    if (m1 != null) {
      final v = m1.group(1)?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final m2 = RegExp(
      r'''name\s*=\s*['"]csrf-token['"][^>]*content\s*=\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    ).firstMatch(html);
    if (m2 != null) {
      final v = m2.group(1)?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// 模拟浏览器首访 Desk：`GET /app`，把响应里的 `Set-Cookie`（如 `csrf_token`）并入当前会话。
  ///
  /// 纯 `login` API 有时只下发 `sid`；原生 POST（切换公司等）依赖 `X-Frappe-CSRF-Token`，
  /// WebView 内 Desk 的 XHR 也依赖完整 Cookie，故登录/冷启动后应至少合并一次。
  static Future<List<Cookie>> mergeCookiesFromDeskBootstrap({
    required Uri siteOrigin,
    required List<Cookie> cookies,
  }) async {
    if (cookies.isEmpty) return cookies;
    final uri = siteOrigin.replace(path: '/app');
    final client = _newHttpClient();
    try {
      final req = await client.getUrl(uri);
      _attachCookies(req, siteOrigin.host, cookies);
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      final extra = _collectCookies(res, siteOrigin.host);
      final byName = <String, Cookie>{for (final c in cookies) c.name: c};
      for (final c in extra) {
        byName[c.name] = c;
      }
      if (csrfTokenFromCookies(byName.values.toList()) == null &&
          text.isNotEmpty) {
        final extracted = _tryParseCsrfFromDeskHtml(text);
        if (extracted != null && extracted.isNotEmpty) {
          byName['csrf_token'] = Cookie('csrf_token', extracted)
            ..domain = siteOrigin.host
            ..path = '/';
        }
      }
      return byName.values.toList();
    } catch (_) {
      return cookies;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> logout({
    required Uri siteOrigin,
    required String sidValue,
  }) async {
    final uri = CosFrappeApiMethods.uri(siteOrigin, CosFrappeApiMethods.logout);
    final client = _newHttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      _attachCookies(req, siteOrigin.host, [
        Cookie('sid', sidValue)..domain = siteOrigin.host..path = '/',
      ]);
      await req.close();
    } catch (_) {
      // 忽略登出网络错误，本地仍清理会话
    } finally {
      client.close(force: true);
    }
  }

  /// 与 [CosAuthService] 持久化格式一致：JSON 列表 + 覆盖 `sid`。
  static List<Cookie> cookiesFromPersistedJson({
    required String? frappeCookiesJson,
    required String host,
    required String? sidValue,
  }) {
    final out = <Cookie>[];
    if (frappeCookiesJson != null && frappeCookiesJson.isNotEmpty) {
      try {
        final list = jsonDecode(frappeCookiesJson) as List<dynamic>;
        for (final e in list) {
          final m = Map<String, dynamic>.from(e as Map);
          final c = Cookie(m['name']! as String, m['value']! as String);
          c.domain = (m['domain'] as String?) ?? host;
          c.path = (m['path'] as String?) ?? '/';
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
          out.add(c);
        }
      } catch (_) {}
    }
    if (sidValue != null && sidValue.isNotEmpty) {
      final idx = out.indexWhere((c) => c.name == 'sid');
      final sidCookie = Cookie('sid', sidValue)
        ..domain = host
        ..path = '/';
      if (idx >= 0) {
        out[idx] = sidCookie;
      } else {
        out.add(sidCookie);
      }
    }
    return out;
  }

  static String? csrfTokenFromCookies(List<Cookie> cookies) {
    for (final c in cookies) {
      if (c.name.toLowerCase() == 'csrf_token') return c.value;
    }
    return null;
  }

  /// 调用 [CosFrappeApiMethods.getCsrfTokenForNativeShell]，把服务端会话里的 CSRF 写入 Cookie 列表。
  ///
  /// 解决：会话内已有 `csrf_token` 但原生端未从 `/app` 收到 Set-Cookie 时，POST 会被 Frappe 判为「无效请求」。
  static Future<List<Cookie>> mergeCsrfFromShellTokenApi({
    required Uri siteOrigin,
    required List<Cookie> cookies,
  }) async {
    if (cookies.isEmpty) return cookies;
    final res = await callMethodGet(
      siteOrigin: siteOrigin,
      cookies: cookies,
      dottedMethod: CosFrappeApiMethods.getCsrfTokenForNativeShell,
      invalidateSessionOnAuthFailure: false,
    );
    if (!res.ok || res.message is! Map) {
      return cookies;
    }
    final m = Map<String, dynamic>.from(res.message as Map);
    final t = m['csrf_token']?.toString();
    if (t == null || t.isEmpty) return cookies;
    final host = siteOrigin.host;
    final byName = <String, Cookie>{for (final c in cookies) c.name: c};
    byName['csrf_token'] = Cookie('csrf_token', t)
      ..domain = host
      ..path = '/';
    return byName.values.toList();
  }

  /// 仅在高度确信「站点会话已失效」时清本机登录态（勿把业务 Permission 当成登出）。
  static Future<void> _applyAuthFailureFromRpc(FrappeRpcResult r) async {
    if (r.ok || !r.shouldInvalidateNativeSession) return;
    await CosAuthService.instance.clearSessionExpectRelogin();
  }

  /// [invalidateSessionOnAuthFailure]：为 false 时，鉴权类失败**不会**触发 [CosAuthService.clearSessionExpectRelogin]。
  ///
  /// 用于 `issue_token_from_session` 等**辅助**接口：其失败只表示「本次未换发 wpt」，不代表应删除本机
  /// Frappe `sid`；否则冷启动 Cookie 尚未稳定时一次 Login required 就会整段误清会话（表现为杀后台后必重登）。
  static Future<FrappeRpcResult> callMethodGet({
    required Uri siteOrigin,
    required List<Cookie> cookies,
    required String dottedMethod,
    bool invalidateSessionOnAuthFailure = true,
  }) async {
    final uri = siteOrigin.replace(path: CosFrappeApiMethods.pathFor(dottedMethod));
    final client = _newHttpClient();
    try {
      final req = await client.getUrl(uri);
      _attachCookies(req, siteOrigin.host, cookies);
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      final parsed = _parseRpcResponse(res.statusCode, text);
      if (invalidateSessionOnAuthFailure) {
        await _applyAuthFailureFromRpc(parsed);
      }
      return parsed;
    } on SocketException catch (e) {
      return FrappeRpcResult.failure('网络错误：${e.message}');
    } on HandshakeException catch (e) {
      return FrappeRpcResult.failure('TLS 握手失败：${e.message}');
    } catch (e) {
      return FrappeRpcResult.failure('$e');
    } finally {
      client.close(force: true);
    }
  }

  static Future<FrappeRpcResult> callMethodPostForm({
    required Uri siteOrigin,
    required List<Cookie> cookies,
    required String dottedMethod,
    required Map<String, String> fields,
    bool invalidateSessionOnAuthFailure = true,
  }) async {
    final uri = siteOrigin.replace(path: CosFrappeApiMethods.pathFor(dottedMethod));
    final client = _newHttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      final csrf = csrfTokenFromCookies(cookies);
      if (csrf != null && csrf.isNotEmpty) {
        req.headers.set('X-Frappe-CSRF-Token', csrf);
      }
      _attachCookies(req, siteOrigin.host, cookies);
      final bodyMap = Map<String, String>.from(fields);
      if (csrf != null &&
          csrf.isNotEmpty &&
          !bodyMap.containsKey('csrf_token')) {
        bodyMap['csrf_token'] = csrf;
      }
      final body = bodyMap.entries
          .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      req.write(body);
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      final parsed = _parseRpcResponse(res.statusCode, text);
      if (invalidateSessionOnAuthFailure) {
        await _applyAuthFailureFromRpc(parsed);
      }
      if (!parsed.ok) {
        return parsed;
      }
      List<Cookie>? mergedFromResponse;
      final extra = _collectCookies(res, siteOrigin.host);
      if (extra.isNotEmpty) {
        final byName = <String, Cookie>{for (final c in cookies) c.name: c};
        for (final c in extra) {
          byName[c.name] = c;
        }
        mergedFromResponse = byName.values.toList();
      }
      if (mergedFromResponse == null) {
        return parsed;
      }
      return FrappeRpcResult.success(
        parsed.message,
        httpStatus: parsed.httpStatus,
        mergedSessionCookies: mergedFromResponse,
      );
    } on SocketException catch (e) {
      return FrappeRpcResult.failure('网络错误：${e.message}');
    } on HandshakeException catch (e) {
      return FrappeRpcResult.failure('TLS 握手失败：${e.message}');
    } catch (e) {
      return FrappeRpcResult.failure('$e');
    } finally {
      client.close(force: true);
    }
  }

  static String? _frappeExceptionText(dynamic ex) {
    if (ex is String && ex.isNotEmpty) return ex;
    if (ex is List) {
      final buf = StringBuffer();
      for (final e in ex) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty) {
          if (buf.isNotEmpty) buf.writeln();
          buf.write(s);
        }
      }
      if (buf.isNotEmpty) return buf.toString();
    }
    return null;
  }

  static String? _frappeServerMessagesText(dynamic sm) {
    if (sm is! String || sm.isEmpty) return null;
    try {
      final d = jsonDecode(sm);
      if (d is List) {
        final parts = <String>[];
        for (final e in d) {
          if (e == null) continue;
          var s = e.toString();
          if (s.isEmpty) continue;
          try {
            final inner = jsonDecode(s);
            if (inner is Map && inner['message'] != null) {
              s = inner['message'].toString();
            }
          } catch (_) {}
          if (s.isNotEmpty) parts.add(s);
        }
        if (parts.isNotEmpty) return parts.join('\n');
      }
    } catch (_) {}
    return null;
  }

  static FrappeRpcResult _parseRpcResponse(int status, String text) {
    Map<String, dynamic>? map;
    try {
      final d = jsonDecode(text);
      if (d is Map<String, dynamic>) map = d;
      // jsonDecode 可能为 Map<dynamic, dynamic>
      if (map == null && d is Map) {
        map = Map<String, dynamic>.from(d);
      }
    } catch (_) {}
    final excTypeStr = map != null ? map['exc_type']?.toString() : null;
    if (map != null && map['exc_type'] != null) {
      final fromEx = _frappeExceptionText(map['exception']);
      if (fromEx != null) {
        return FrappeRpcResult.failure(
          fromEx,
          httpStatus: status,
          excType: excTypeStr,
        );
      }
      final fromSm = _frappeServerMessagesText(map['_server_messages']);
      if (fromSm != null) {
        return FrappeRpcResult.failure(
          fromSm,
          httpStatus: status,
          excType: excTypeStr,
        );
      }
      final et = map['exc_type']?.toString();
      if (et != null && et.isNotEmpty) {
        return FrappeRpcResult.failure(et, httpStatus: status, excType: excTypeStr);
      }
      return FrappeRpcResult.failure(
        '服务器错误',
        httpStatus: status,
        excType: excTypeStr,
      );
    }
    if (status >= 400) {
      return FrappeRpcResult.failure(
        text.length > 200 ? '${text.substring(0, 200)}…' : text,
        httpStatus: status,
      );
    }
    if (map != null && map.containsKey('message')) {
      return FrappeRpcResult.success(map['message'], httpStatus: status);
    }
    return FrappeRpcResult.failure('无效响应', httpStatus: status);
  }

  static void _attachCookies(HttpClientRequest req, String host, List<Cookie> cookies) {
    if (cookies.isEmpty) return;
    final parts = <String>[];
    for (final c in cookies) {
      parts.add('${c.name}=${c.value}');
    }
    req.headers.set(HttpHeaders.cookieHeader, parts.join('; '));
  }

  static String _formatError(Map<String, dynamic>? map, String raw) {
    if (map == null) return raw.length > 200 ? '${raw.substring(0, 200)}…' : raw;
    final ex = map['exception'];
    if (ex is String && ex.isNotEmpty) return ex;
    final msg = map['message'];
    if (msg is String && msg.isNotEmpty && msg != 'Logged In') return msg;
    return '登录失败（HTTP）';
  }
}

class FrappeLoginOutcome {
  FrappeLoginOutcome._({
    required this.ok,
    this.cookies = const [],
    this.rawJson,
    this.errorMessage,
  });

  factory FrappeLoginOutcome.ok({
    required List<Cookie> cookies,
    Map<String, dynamic>? rawJson,
  }) {
    return FrappeLoginOutcome._(ok: true, cookies: cookies, rawJson: rawJson);
  }

  factory FrappeLoginOutcome.fail(String message) {
    return FrappeLoginOutcome._(ok: false, errorMessage: message);
  }

  final bool ok;
  final List<Cookie> cookies;
  final Map<String, dynamic>? rawJson;
  final String? errorMessage;

  String? get sidValue {
    for (final c in cookies) {
      if (c.name == 'sid') return c.value;
    }
    return null;
  }
}

class WorkerPortalTokenOutcome {
  WorkerPortalTokenOutcome._({
    required this.ok,
    this.token,
    this.errorMessage,
  });

  factory WorkerPortalTokenOutcome.ok(String token) {
    return WorkerPortalTokenOutcome._(ok: true, token: token);
  }

  factory WorkerPortalTokenOutcome.fail(String message) {
    return WorkerPortalTokenOutcome._(ok: false, errorMessage: message);
  }

  final bool ok;
  final String? token;
  final String? errorMessage;
}
