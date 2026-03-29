/// 与 DocType「COS Work Mini Program」字段 `nav_bar_inset_mode` 及 API 对齐。
/// 取值：none | safe_area | app_bar（默认 safe_area）。
enum CosMiniProgramNavBarInsetMode {
  /// 不预留顶栏区（WebView 全屏叠在顶栏下，H5 顶留白 0）
  none,

  /// App 将 WebView 下推 `viewPadding.top`（仅状态栏高度）；H5 `--cos-content-padding-top` 为 0；壳叠层仍为 状态栏+44
  safeArea,

  /// WebView 全屏叠在顶栏下，H5 须 安全区+44px
  appBar,
}

CosMiniProgramNavBarInsetMode parseNavBarInsetMode(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'none':
      return CosMiniProgramNavBarInsetMode.none;
    case 'safe_area':
    case 'status_bar':
    case 'status_bar_only':
      return CosMiniProgramNavBarInsetMode.safeArea;
    case 'app_bar':
    case 'app_provided':
      return CosMiniProgramNavBarInsetMode.appBar;
    case 'page_custom':
      return CosMiniProgramNavBarInsetMode.none;
    default:
      return CosMiniProgramNavBarInsetMode.safeArea;
  }
}
