import 'package:flutter/material.dart';

import 'cos_mini_program_nav_bar_inset_mode.dart';
import 'mini_program_material_icons.dart';

/// 小程序 WebView 认证策略（见 `docs/cos-mini-program-token-auth-plan.md`）。
enum CosMiniProgramAuthKind {
  /// Frappe Cookie（`sid` 等），与 Desk 一致；所有小程序 WebView 均走此方式。
  frappeSession,
}

/// 一个业务「小程序」：路径相对于站点根，由 [launchUriFor] 与当前 [CosSiteStore] 组合。
///
/// 图标：`iconUrl` 非空时优先网络/站内图片；否则使用 [materialIcon]（可由服务端 `icon_key` 映射）。
class CosMiniProgram {
  CosMiniProgram({
    required this.id,
    required this.title,
    required this.launchPath,
    IconData? icon,
    this.iconUrl,
    this.subtitle,
    this.accentColor,
    this.authKind = CosMiniProgramAuthKind.frappeSession,
    this.serverDocName,
    this.programEnabled = true,
    this.userPinnedOnLauncher = false,
    this.navBarInsetMode = CosMiniProgramNavBarInsetMode.safeArea,
    /// 为 false 时根页也不显示壳顶栏居中标题（H5 自绘标题/搜索时可关）。
    this.showNavBarTitle = true,
  }) : materialIcon = icon;

  final String id;

  /// Frappe「COS Work Mini Program」文档名；内置注册表入口为 null。
  final String? serverDocName;

  /// 后台「COS Work Mini Program」是否勾选启用；停用时客户端灰显但仍可占位。
  final bool programEnabled;

  /// 是否因「用户自选小程序」出现在首页（与角色默认区分）。
  final bool userPinnedOnLauncher;
  final String title;
  final String? subtitle;

  /// 以 `/` 开头的站内路径，如 `/worker-portal/...`。
  final String launchPath;

  /// Material 图标（与 `icon_key` 或代码内注册对应）。
  final IconData? materialIcon;

  /// 服务端配置的图标 URL（可 https 完整链或 `/files/...` 等站内路径）。
  final String? iconUrl;

  final Color? accentColor;

  /// 与 Desk 相同：依赖 Frappe 会话 Cookie；Desk 中历史 `worker_portal_token` 亦按此项解析。
  final CosMiniProgramAuthKind authKind;

  /// 壳内 H5 顶栏占位策略（与 DocType `nav_bar_inset_mode` 一致）。
  final CosMiniProgramNavBarInsetMode navBarInsetMode;

  /// 是否在 [WeChatMiniProgramNavBar] 中显示居中标题（与 `showTitle: !_canGoBack` 组合使用）。
  final bool showNavBarTitle;

  /// 解析后的可加载 URL；相对路径基于 [siteOrigin]。
  String? resolvedIconUrl(Uri siteOrigin) {
    final raw = (iconUrl ?? '').trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/')) {
      return siteOrigin.resolve(raw).toString();
    }
    return null;
  }

  /// 查询参数 `__cos_work_shell=1` 供 Frappe 识别壳内首跳（与自定义 User-Agent 互补）。
  static const cosWorkShellQueryKey = '__cos_work_shell';

  Uri launchUriFor(Uri siteOrigin) {
    final p = launchPath.startsWith('/') ? launchPath : '/$launchPath';
    final base = siteOrigin.replace(path: p);
    final q = Map<String, String>.from(base.queryParameters);
    q[cosWorkShellQueryKey] = '1';
    return base.replace(queryParameters: q);
  }

  static CosMiniProgramAuthKind _parseAuthKind(String? _) {
    return CosMiniProgramAuthKind.frappeSession;
  }

  static bool _parseProgramEnabled(Map<String, dynamic> m) {
    if (!m.containsKey('program_enabled')) return true;
    final v = m['program_enabled'];
    if (v == false || v == 0 || v == '0') return false;
    return true;
  }

  static bool _parseUserPinned(Map<String, dynamic> m) {
    final v = m['user_pinned'];
    if (v == true || v == 1 || v == '1') return true;
    return false;
  }

  static bool _parseShowNavBarTitle(Map<String, dynamic> m) {
    if (!m.containsKey('show_nav_bar_title')) return true;
    final v = m['show_nav_bar_title'];
    if (v == false) return false;
    if (v == 0 || v == 0.0) return false;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == '0' || s == 'false' || s == 'no') return false;
    }
    return true;
  }

  static Color? _parseAccent(String? raw) {
    if (raw == null) return null;
    var h = raw.trim();
    if (h.isEmpty) return null;
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length != 6) return null;
    try {
      final v = int.parse(h, radix: 16);
      return Color(0xFF000000 | v);
    } catch (_) {
      return null;
    }
  }

  /// 由 `cos.work_app_launcher_api.get_launcher_programs` 单条 JSON 构造。
  factory CosMiniProgram.fromLauncherPayload(
    Map<String, dynamic> m,
    Uri siteOrigin,
  ) {
    final id = m['id']?.toString().trim() ?? '';
    final title = m['title']?.toString().trim() ?? '';
    var path = m['launch_path']?.toString().trim() ?? '';
    if (path.isNotEmpty && !path.startsWith('/')) {
      path = '/$path';
    }
    final iconKey = m['icon_key']?.toString();
    final iconUrlRaw = m['icon_url']?.toString().trim() ?? '';
    final docRaw =
        (m['doc_name'] ?? m['name'])?.toString().trim() ?? '';

    return CosMiniProgram(
      id: id.isEmpty ? 'unknown' : id,
      title: title.isEmpty ? id : title,
      subtitle: (m['subtitle'] ?? m['description'])?.toString().trim(),
      launchPath: path.isEmpty ? '/' : path,
      icon: MiniProgramMaterialIcons.resolve(iconKey),
      iconUrl: iconUrlRaw.isEmpty ? null : iconUrlRaw,
      accentColor: _parseAccent(m['accent_color']?.toString()),
      authKind: _parseAuthKind(m['auth_kind']?.toString()),
      serverDocName: docRaw.isEmpty ? null : docRaw,
      programEnabled: _parseProgramEnabled(m),
      userPinnedOnLauncher: _parseUserPinned(m),
      navBarInsetMode: parseNavBarInsetMode(m['nav_bar_inset_mode']?.toString()),
      showNavBarTitle: _parseShowNavBarTitle(m),
    );
  }
}
