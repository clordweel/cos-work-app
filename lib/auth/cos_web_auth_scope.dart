import 'package:webview_flutter/webview_flutter.dart';

/// 全局 Web 认证与会话（继承关系）说明与集中入口。
///
/// **为何需要「全局」概念**
/// 多个小程序若各自加载同主站（如 `cos.junhai.work`）下的不同路径，应**共用一套 Frappe 会话**，
/// 避免每个入口各登一次。满足设计时，应在壳层明确「会话归谁管、如何延续」。
///
/// **当前实现策略（推荐基线）**
/// - 原生登录成功后由 [CosWebCookieSync] 把 Frappe 下发的 Cookie 写入 WebView（Android 经
///   [MethodChannel]，Cookie 属性串用 [Cookie.toString] 与服务端一致）；[CosAuthService] 会
///   持久化 Cookie 快照，并在打开小程序 WebView **首跳前**再次 [CosAuthService.ensureWebViewCookiesBeforeBrowse]。
///
/// **后续若出现以下情况，再升级此模块**
/// - 小程序改为 **不同子域**（如 `a.junhai.work` 与 `b.junhai.work`）→ 需 Cookie 同步、
///   或统一 **OAuth / API Token** + `flutter_secure_storage`。
/// - 需 **退出登录、切换账套** 等显式操作 → 在此集中调用 Cookie 清理或跳转 `/logout`。
/// - 需 **启动前检测 Guest** → 可在此封装「先打开登录页再回跳」的路由，而不是散落在各小程序。
///
/// **与 [WebViewController] 的配合**
/// 若将来要为所有 WebView 统一设置 User-Agent、第三方 Cookie、或预灌 Cookie，
/// 可在此处扩展 `prepareController(WebViewController c)` 并在创建各小程序 WebView 时调用。
abstract final class CosWebAuthScope {
  /// 预留：创建任意小程序 [WebViewController] 后调用，用于未来统一注入规则。
  static void prepareWebViewController(WebViewController _) {
    // 当前无额外逻辑；同域 Cookie 由系统 WebView 默认共享。
    // 示例：AndroidCookieManager.sync / setCookie 等可在此集中添加。
  }
}
