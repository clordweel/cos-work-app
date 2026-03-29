/// 与 DocType「COS Work Mini Program」字段 `nav_bar_inset_mode` 及 API 对齐。
/// 取值：none | safe_area | app_bar（默认 safe_area）。
enum CosMiniProgramNavBarInsetMode {
  /// 不预留顶栏区（WebView 全屏叠在顶栏下，H5 顶留白 0）
  none,

  /// WebView 顶对齐状态栏下沿；H5 `--cos-content-padding-top` 为 0，自绘顶栏与叠层 44 同带对齐
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
