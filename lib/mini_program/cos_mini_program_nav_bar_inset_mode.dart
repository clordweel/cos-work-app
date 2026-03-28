/// 与 DocType「COS Work Mini Program」字段 `nav_bar_inset_mode` 及 API `nav_bar_inset_mode` 对齐。
enum CosMiniProgramNavBarInsetMode {
  /// 无额外顶栏占位（H5 自顶向下排；可能与系统状态栏重叠，慎用）
  none,

  /// 仅状态栏高度：壳内不叠 44px 仿微信条，H5 仅预留状态栏区（壳上保留紧凑返回/关闭）
  statusBarOnly,

  /// App 提供状态栏 + 仿微信顶栏（44），与 Worker Portal 默认布局一致
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
    default:
      return CosMiniProgramNavBarInsetMode.appProvided;
  }
}
