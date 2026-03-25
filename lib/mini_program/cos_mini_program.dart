import 'package:flutter/material.dart';

/// 小程序 WebView 认证策略（见 `docs/cos-mini-program-token-auth-plan.md`）。
enum CosMiniProgramAuthKind {
  /// Frappe Cookie（Desk、`/app/*`），允许站内登录页重登。
  frappeSession,

  /// Worker Portal：以 `wpt.` Bearer + `localStorage` 为主，壳在首跳前注入 token。
  workerPortalToken,
}

/// 一个业务「小程序」：路径相对于站点根，由 [launchUriFor] 与当前 [CosSiteStore] 组合。
class CosMiniProgram {
  CosMiniProgram({
    required this.id,
    required this.title,
    required this.launchPath,
    required this.icon,
    this.subtitle,
    this.accentColor,
    this.authKind = CosMiniProgramAuthKind.frappeSession,
  });

  final String id;
  final String title;
  final String? subtitle;

  /// 以 `/` 开头的站点内路径，如 `/worker-portal/...`。
  final String launchPath;
  final IconData icon;
  final Color? accentColor;

  /// 默认 [CosMiniProgramAuthKind.frappeSession]；`/worker-portal/*` 应使用 [CosMiniProgramAuthKind.workerPortalToken]。
  final CosMiniProgramAuthKind authKind;

  Uri launchUriFor(Uri siteOrigin) {
    final p = launchPath.startsWith('/') ? launchPath : '/$launchPath';
    return siteOrigin.replace(path: p, queryParameters: {});
  }
}
