import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 将 [HttpClient] 得到的 Cookie 写入系统 WebView，供小程序 WebView 继承会话。
///
/// **仅支持 Android**：通过 [MethodChannel] 调用原生 `CookieManager.setCookie`；
/// 第一个参数须为带 scheme 的 URL，且应调用 `flush()`。Cookie 的**属性串**使用
/// [Cookie.toString]，以保留服务端下发的 `HttpOnly` / `SameSite` / `Domain` / `Path` 等。
abstract final class CosWebCookieSync {
  static const MethodChannel _androidCookies = MethodChannel(
    'work.junhai.cos_work_app/webview_cookies',
  );

  /// 供 `CookieManager.setCookie(url, …)` 使用的站点根 URL（须含 scheme，建议尾随 `/`）。
  static String cookieSetUrlForOrigin(Uri siteOrigin) {
    final port = siteOrigin.hasPort ? ':${siteOrigin.port}' : '';
    return '${siteOrigin.scheme}://${siteOrigin.host}$port/';
  }

  /// 与首跳页面 URL 一致时，部分 WebView 对 Cookie 关联更稳（可选）。
  static String _cookiePrimeUrl(Uri pageUrl) {
    var u = pageUrl;
    if (u.hasQuery) {
      u = Uri(
        scheme: u.scheme,
        host: u.host,
        port: u.hasPort ? u.port : null,
        path: u.path,
      );
    }
    return u.toString();
  }

  static Future<void> applyCookies(
    Uri siteOrigin,
    List<Cookie> cookies, {
    Uri? primeRequestUrl,
  }) async {
    if (!Platform.isAndroid) {
      if (kDebugMode) {
        debugPrint(
          'CosWebCookieSync: 非 Android，跳过 WebView Cookie（${Platform.operatingSystem}）',
        );
      }
      return;
    }
    await _applyCookiesAndroid(siteOrigin, cookies, primeRequestUrl: primeRequestUrl);
  }

  /// HTTPS 站点下为写入 WebView 的 Cookie 强制 `Secure`，避免属性缺失时 Chromium 拒发会话 Cookie。
  static List<Cookie> _cookiesAdjustedForWebView(Uri siteOrigin, List<Cookie> cookies) {
    if (siteOrigin.scheme != 'https') return cookies;
    return cookies
        .map(
          (c) => Cookie(c.name, c.value)
            ..domain = c.domain
            ..path = c.path ?? '/'
            ..httpOnly = c.httpOnly
            ..sameSite = c.sameSite
            ..maxAge = c.maxAge
            ..expires = c.expires
            ..secure = true,
        )
        .toList();
  }

  static Future<void> _applyCookiesAndroid(
    Uri siteOrigin,
    List<Cookie> cookies, {
    Uri? primeRequestUrl,
  }) async {
    final rootUrl = cookieSetUrlForOrigin(siteOrigin);
    final extra = primeRequestUrl != null &&
            _cookiePrimeUrl(primeRequestUrl) != rootUrl
        ? _cookiePrimeUrl(primeRequestUrl)
        : null;

    final adjusted = _cookiesAdjustedForWebView(siteOrigin, cookies);
    for (final c in adjusted) {
      final value = c.toString();
      await _androidSetCookiePair(rootUrl, value);
      if (extra != null) {
        await _androidSetCookiePair(extra, value);
      }
    }
  }

  static Future<void> _androidSetCookiePair(String url, String cookieValue) async {
    try {
      await _androidCookies.invokeMethod<void>('setCookie', {
        'url': url,
        'value': cookieValue,
      });
    } on PlatformException catch (e, st) {
      debugPrint('CosWebCookieSync Android setCookie failed: $e\n$st');
    }
  }

  static Future<void> applySidOnly(Uri siteOrigin, String sid) async {
    await applyCookies(siteOrigin, [_sidCookie(siteOrigin, sid)]);
  }

  /// 仅 sid、无持久化完整 Cookie 时使用；与 [applySidOnly] 相同但可对目标页 URL 再灌一次。
  static Future<void> applySidOnlyForBrowse(
    Uri siteOrigin,
    String sid, {
    Uri? primeRequestUrl,
  }) async {
    await applyCookies(
      siteOrigin,
      [_sidCookie(siteOrigin, sid)],
      primeRequestUrl: primeRequestUrl,
    );
  }

  static Cookie _sidCookie(Uri siteOrigin, String sid) {
    final c = Cookie('sid', sid)..path = '/';
    if (siteOrigin.scheme == 'https') {
      c.secure = true;
    }
    return c;
  }

  static Future<void> clearAll() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _androidCookies.invokeMethod<void>('clearAllCookies');
    } on PlatformException catch (e, st) {
      debugPrint('CosWebCookieSync Android clearAll failed: $e\n$st');
    }
  }
}
