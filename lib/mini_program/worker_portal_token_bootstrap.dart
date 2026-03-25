import 'dart:convert';

/// 与 `vendor/cos/cos/worker_portal/src/lib/api.ts` 中 `TOKEN_KEY` 一致。
const String kWorkerPortalTokenStorageKey = 'cos_worker_portal_token';

/// 在同源 [baseUrl] 下写入 `localStorage` 后跳转到 Worker Portal 目标页（避免 SPA 首屏读不到 token）。
abstract final class WorkerPortalTokenBootstrap {
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
