import 'package:flutter/material.dart';

import '../mini_program/cos_mini_program.dart';

/// 注册各业务入口（路径相对服务器根地址）。
abstract final class MiniProgramRegistry {
  static final CosMiniProgram piReimbursementPending = CosMiniProgram(
    id: 'pi_reimbursement_pending',
    title: '待报销采购发票',
    subtitle: '员工垫付 · 待审批',
    launchPath: '/worker-portal/pi-reimbursement-pending',
    icon: Icons.fact_check_outlined,
    accentColor: const Color(0xFF1565C0),
    authKind: CosMiniProgramAuthKind.workerPortalToken,
  );

  static final CosMiniProgram piReimbursementApproval = CosMiniProgram(
    id: 'pi_reimbursement_approval',
    title: '报销处理',
    subtitle: '审批处理入口',
    launchPath: '/worker-portal/pi-reimbursement-approval',
    icon: Icons.link_outlined,
    accentColor: const Color(0xFF5E35B1),
    authKind: CosMiniProgramAuthKind.workerPortalToken,
  );

  static final CosMiniProgram stockReconciliation = CosMiniProgram(
    id: 'stock_reconciliation',
    title: '库存盘点',
    subtitle: '库存盘点单据',
    launchPath: '/app/stock-reconciliation',
    icon: Icons.inventory_2_outlined,
    accentColor: const Color(0xFF2E7D32),
    authKind: CosMiniProgramAuthKind.frappeSession,
  );

  static final CosMiniProgram deskHome = CosMiniProgram(
    id: 'desk_home',
    title: '工作台',
    subtitle: '完整管理界面',
    launchPath: '/desk',
    icon: Icons.dashboard_outlined,
    accentColor: const Color(0xFF37474F),
    authKind: CosMiniProgramAuthKind.frappeSession,
  );

  /// 壳内调试：网络与会话（不加载 WebView，见 [CosNavigation.openMiniProgram]）。
  static final CosMiniProgram shellNetworkDebug = CosMiniProgram(
    id: 'shell_network_debug',
    title: '调试·网络认证',
    subtitle: '站点 / sid / wpt / RPC',
    launchPath: '/__shell_debug__',
    icon: Icons.bug_report_outlined,
    accentColor: const Color(0xFF6D4C41),
    authKind: CosMiniProgramAuthKind.frappeSession,
  );

  /// 首页宫格（不含登录；登录由原生页完成）。
  static final List<CosMiniProgram> forLauncherGrid = [
    piReimbursementPending,
    piReimbursementApproval,
    stockReconciliation,
    deskHome,
    shellNetworkDebug,
  ];

  static CosMiniProgram? tryFindById(String id) {
    for (final p in forLauncherGrid) {
      if (p.id == id) return p;
    }
    return null;
  }
}
