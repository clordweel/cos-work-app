/// 与 COS（`vendor/cos`）白名单方法名对齐的单一事实来源。
///
/// 服务端实现参考：
/// - `cos/work_app_launcher_api.py`（小程序宫格 / 市场 / 用户自选）
/// - `cos.company_context_api`（公司上下文）
/// - `cos.worker_portal_api.login_for_token` / `issue_token_from_session`（Worker Portal `wpt.`）
///
/// 变更后端方法名时须同步此处与集成测试场景。
abstract final class CosFrappeApiMethods {
  CosFrappeApiMethods._();

  /// Frappe `/api/method/<name>` 的路径（含前导 `/`）。
  static String pathFor(String methodName) => '/api/method/$methodName';

  static Uri uri(Uri siteOrigin, String methodName) =>
      siteOrigin.replace(path: pathFor(methodName));

  // —— Frappe 核心 ——
  static const String login = 'login';
  static const String logout = 'logout';
  static const String getLoggedUser = 'frappe.auth.get_logged_user';

  // —— COS Worker Portal ——
  static const String workerPortalLoginForToken =
      'cos.worker_portal_api.login_for_token';
  static const String issueWorkerPortalTokenFromSession =
      'cos.worker_portal_api.issue_token_from_session';

  // —— COS 公司上下文 ——
  static const String listAccessibleCompanies =
      'cos.company_context_api.list_accessible_companies';
  static const String getSessionCompany =
      'cos.company_context_api.get_session_company';
  static const String setDefaultCompany =
      'cos.company_context_api.set_default_company';

  // —— COS 工作台小程序启动器 ——
  static const String getLauncherPrograms =
      'cos.work_app_launcher_api.get_launcher_programs';
  static const String getMarketPrograms =
      'cos.work_app_launcher_api.get_market_programs';
  static const String addUserMiniProgram =
      'cos.work_app_launcher_api.add_user_mini_program';
  static const String removeUserMiniProgram =
      'cos.work_app_launcher_api.remove_user_mini_program';
}
