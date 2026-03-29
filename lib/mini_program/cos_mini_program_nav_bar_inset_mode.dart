/// 与 DocType「COS Work Mini Program」字段 `nav_bar_inset_mode` 及 API `nav_bar_inset_mode` 对齐。
enum CosMiniProgramNavBarInsetMode {
  /// 无额外顶栏占位（H5 自顶向下排；可能与系统状态栏重叠，慎用）
  none,

  /// App 将 WebView 布局在原生顶栏之下；H5 `--cos-content-padding-top` 为 0。
  statusBarOnly,

  /// WebView 全屏叠在顶栏下；H5 须 `安全区+44px` 顶留白。
  appProvided,

  /// 页面自定义：不注入顶栏占位，由 H5 自行处理；仍注入 `--cos-status-bar-height` 等变量供选用
  pageCustom,
}

CosMiniProgramNavBarInsetMode parseNavBarInsetMode(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'none':
      return CosMiniProgramNavBarInsetMode.none;
    case 'status_bar_only':
      return CosMiniProgramNavBarInsetMode.statusBarOnly;
    case 'page_custom':
      return CosMiniProgramNavBarInsetMode.pageCustom;
    case 'app_provided':
      return CosMiniProgramNavBarInsetMode.appProvided;
    default:
      return CosMiniProgramNavBarInsetMode.statusBarOnly;
  }
}
