import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  });

  factory FrappeRpcResult.success(dynamic message) =>
      FrappeRpcResult._(ok: true, message: message);

  factory FrappeRpcResult.failure(String text) =>
      FrappeRpcResult._(ok: false, errorText: text);

  final bool ok;
  final dynamic message;
  final String? errorText;
}

/// 使用 [HttpClient] 调用 Frappe 登录/会话接口（不经过 WebView）。
abstract final class FrappeNativeSession {
  static Future<FrappeLoginOutcome> login({
    required Uri siteOrigin,
    required String usr,
    required String pwd,
  }) async {
    final uri = siteOrigin.replace(path: '/api/method/login');
    final client = HttpClient();
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

      final cookies = res.cookies;
      final hasSid = cookies.any((c) => c.name == 'sid');
      if (!hasSid) {
        return FrappeLoginOutcome.fail('服务器未返回会话 Cookie（sid），请检查站点地址与 HTTPS。');
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
    final uri = siteOrigin.replace(path: '/api/method/frappe.auth.get_logged_user');
    final client = HttpClient();
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

  /// 与 [verifySession] 相同入参，但区分「真失效」与「无法连接服务器」。
  static Future<FrappeSessionVerifyResult> verifySessionDetailed({
    required Uri siteOrigin,
    required String sidValue,
  }) async {
    final uri = siteOrigin.replace(path: '/api/method/frappe.auth.get_logged_user');
    final client = HttpClient();
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

      if (map != null && map['exc_type'] != null) {
        return FrappeSessionVerifyResult.unauthenticated;
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
    final uri = siteOrigin.replace(path: '/api/method/cos.worker_portal_api.login_for_token');
    final client = HttpClient();
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

  static Future<void> logout({
    required Uri siteOrigin,
    required String sidValue,
  }) async {
    final uri = siteOrigin.replace(path: '/api/method/logout');
    final client = HttpClient();
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

  static Future<FrappeRpcResult> callMethodGet({
    required Uri siteOrigin,
    required List<Cookie> cookies,
    required String dottedMethod,
  }) async {
    final uri = siteOrigin.replace(path: '/api/method/$dottedMethod');
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      _attachCookies(req, siteOrigin.host, cookies);
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      return _parseRpcResponse(res.statusCode, text);
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
  }) async {
    final uri = siteOrigin.replace(path: '/api/method/$dottedMethod');
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      final csrf = csrfTokenFromCookies(cookies);
      if (csrf != null && csrf.isNotEmpty) {
        req.headers.set('X-Frappe-CSRF-Token', csrf);
      }
      _attachCookies(req, siteOrigin.host, cookies);
      final body = fields.entries
          .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      req.write(body);
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      return _parseRpcResponse(res.statusCode, text);
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

  static FrappeRpcResult _parseRpcResponse(int status, String text) {
    Map<String, dynamic>? map;
    try {
      final d = jsonDecode(text);
      if (d is Map<String, dynamic>) map = d;
    } catch (_) {}
    if (map != null && map['exc_type'] != null) {
      final ex = map['exception'];
      if (ex is String && ex.isNotEmpty) {
        return FrappeRpcResult.failure(ex);
      }
      return FrappeRpcResult.failure('服务器错误');
    }
    if (status >= 400) {
      return FrappeRpcResult.failure(
        text.length > 200 ? '${text.substring(0, 200)}…' : text,
      );
    }
    if (map != null && map.containsKey('message')) {
      return FrappeRpcResult.success(map['message']);
    }
    return FrappeRpcResult.failure('无效响应');
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
