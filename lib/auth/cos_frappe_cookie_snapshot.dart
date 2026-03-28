import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'cos_session_storage_keys.dart';
import 'cos_web_cookie_sync.dart';

/// 将 Frappe Cookie 快照写入本地并与 WebView（Android）对齐。
///
/// 与 [CosAuthService] 内持久化结构一致，供切换公司、小程序自选等避免循环依赖。
Future<void> persistFrappeCookieSnapshotAndSyncWebView({
  required Uri siteOrigin,
  required List<Cookie> cookies,
}) async {
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
  await CosWebCookieSync.applyCookies(siteOrigin, cookies);
}
