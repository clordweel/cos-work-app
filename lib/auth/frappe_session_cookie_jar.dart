import 'dart:io';

/// Frappe 会话 Cookie 合并与持久化前的规整（无业务层依赖，避免 import 环）。
abstract final class FrappeSessionCookieJar {
  /// 合并服务端 `Set-Cookie` 时：禁止用空值 / Guest 覆盖当前 `sid`。
  static void mergeResponseCookiesIntoJar(
    Map<String, Cookie> byName,
    List<Cookie> fromResponse,
  ) {
    for (final c in fromResponse) {
      if (c.name == 'sid') {
        final v = c.value.trim();
        if (v.isEmpty || v.toLowerCase() == 'guest') {
          continue;
        }
      }
      byName[c.name] = c;
    }
  }

  /// 写入磁盘或灌入 WebView 前：去掉无效 `sid`，并以 Keychain 中的 [sidValue] 为准写回 `sid`。
  static List<Cookie> prepareCookiesForPersistence(
    List<Cookie> cookies,
    String host,
    String? sidValue,
  ) {
    final filtered = <Cookie>[];
    for (final c in cookies) {
      if (c.name == 'sid') {
        final v = c.value.trim();
        if (v.isEmpty || v.toLowerCase() == 'guest') {
          continue;
        }
      }
      filtered.add(c);
    }
    if (sidValue != null && sidValue.isNotEmpty) {
      final idx = filtered.indexWhere((x) => x.name == 'sid');
      final sidCookie = Cookie('sid', sidValue)
        ..domain = host
        ..path = '/';
      if (idx >= 0) {
        filtered[idx] = sidCookie;
      } else {
        filtered.add(sidCookie);
      }
    }
    return filtered;
  }
}
