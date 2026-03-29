/// 与 DocType「COS Work Mini Program」字段 `nav_bar_inset_mode` 及 API 对齐。
/// 取值：none | status_bar | app_bar（默认 status_bar）。
enum CosMiniProgramNavBarInsetMode {
  /// 不预留顶栏区（WebView 全屏叠在顶栏下，H5 顶留白 0）
  none,

  /// WebView 从系统状态栏下沿起算，44px 顶栏叠在 WebView 上；H5 为 `--cos-nav-bar-height`（44px）
  statusBar,

  /// WebView 全屏叠在顶栏下，H5 须 安全区+44px
  appBar,
}

CosMiniProgramNavBarInsetMode parseNavBarInsetMode(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'none':
      return CosMiniProgramNavBarInsetMode.none;
    case 'status_bar':
    case 'status_bar_only':
      return CosMiniProgramNavBarInsetMode.statusBar;
    case 'app_bar':
    case 'app_provided':
      return CosMiniProgramNavBarInsetMode.appBar;
    case 'page_custom':
      return CosMiniProgramNavBarInsetMode.none;
    default:
      return CosMiniProgramNavBarInsetMode.statusBar;
  }
}
