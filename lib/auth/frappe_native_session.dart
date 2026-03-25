import 'dart:convert';
import 'dart:io';

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

  static Future<bool> verifySession({
    required Uri siteOrigin,
    required String sidValue,
  }) async {
    final user = await getLoggedUser(
      siteOrigin: siteOrigin,
      cookies: [Cookie('sid', sidValue)..domain = siteOrigin.host..path = '/'],
    );
    return user != null;
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
