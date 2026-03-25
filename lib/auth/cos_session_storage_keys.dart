/// 与 [CosAuthService] 共用的持久化键，供账套等模块读取 Cookie 快照而不循环依赖 Auth。
abstract final class CosSessionKeys {
  static const frappeSid = 'cos_frappe_sid';
  static const frappeWebCookiesJson = 'cos_frappe_web_cookies_json';
}
