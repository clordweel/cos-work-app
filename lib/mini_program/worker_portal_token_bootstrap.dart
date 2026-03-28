import 'dart:convert';

/// 与 `vendor/cos/cos/worker_portal/src/main.tsx` 中 `WPT_HASH_PREFIX` 一致。
const String kWorkerPortalTokenHashPrefix = 'cosWorkerPortalToken=';

/// 与 `vendor/cos/cos/worker_portal/src/lib/api.ts` 中 `TOKEN_KEY` 一致。
const String kWorkerPortalTokenStorageKey = 'cos_worker_portal_token';

/// Worker Portal 在 Flutter WebView 中的 token 注入。
///
/// **勿再使用** [htmlRedirect]：`loadHtmlString` 在临时文档中写入的 `localStorage` 与导航后的
/// `https://站点/...` **不同源**，令牌无法带到小程序页。应使用 [uriWithEmbeddedToken] 走同源首跳，
/// 由站点脚本从 URL hash 同步写入 `localStorage`。
abstract final class WorkerPortalTokenBootstrap {
  /// 在目标 URL 上附加一次性 hash，供 Worker Portal 首屏脚本写入 `localStorage` 后 `replaceState` 清除。
  static Uri uriWithEmbeddedToken(Uri target, String token) {
    final enc = Uri.encodeComponent(token);
    return target.replace(fragment: '$kWorkerPortalTokenHashPrefix$enc');
  }

  @Deprecated('Use uriWithEmbeddedToken + loadRequest：loadHtmlString 无法跨文档共享 localStorage')
  static String htmlRedirect({
    required String token,
    required Uri target,
  }) {
    final keyLit = jsonEncode(kWorkerPortalTokenStorageKey);
    final tokenLit = jsonEncode(token);
    final targetLit = jsonEncode(target.toString());
    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head><body>
<script>
try { localStorage.setItem($keyLit, $tokenLit); } catch (e) {}
location.replace($targetLit);
</script>
</body></html>''';
  }
}
