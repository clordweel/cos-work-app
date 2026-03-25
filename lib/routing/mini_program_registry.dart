import 'package:flutter/material.dart';

import '../mini_program/cos_mini_program.dart';

/// Alpha：业务页由 Frappe 承载；在此注册相对路径，运行时与 [CosSiteStore] 拼成完整 URL。
abstract final class MiniProgramRegistry {
  static final CosMiniProgram piReimbursementPending = CosMiniProgram(
    id: 'pi_reimbursement_pending',
    title: '报销审批',
    subtitle: '待审批的采购发票',
    launchPath: '/worker-portal/pi-reimbursement-pending',
    icon: Icons.fact_check_outlined,
    accentColor: const Color(0xFF1565C0),
    authKind: CosMiniProgramAuthKind.workerPortalToken,
  );

  static final CosMiniProgram piReimbursementApproval = CosMiniProgram(
    id: 'pi_reimbursement_approval',
    title: '报销审批(外链)',
    subtitle: '凭审批链访问，或从待办进入',
    launchPath: '/worker-portal/pi-reimbursement-approval',
    icon: Icons.link_outlined,
    accentColor: const Color(0xFF5E35B1),
    authKind: CosMiniProgramAuthKind.workerPortalToken,
  );

  static final CosMiniProgram stockReconciliation = CosMiniProgram(
    id: 'stock_reconciliation',
    title: '库存盘点',
    subtitle: 'Stock Reconciliation',
    launchPath: '/app/stock-reconciliation',
    icon: Icons.inventory_2_outlined,
    accentColor: const Color(0xFF2E7D32),
    authKind: CosMiniProgramAuthKind.frappeSession,
  );

  static final CosMiniProgram deskHome = CosMiniProgram(
    id: 'desk_home',
    title: 'Desk',
    subtitle: 'Frappe 工作台',
    launchPath: '/desk',
    icon: Icons.dashboard_outlined,
    accentColor: const Color(0xFF37474F),
    authKind: CosMiniProgramAuthKind.frappeSession,
  );

  /// 首页宫格（不含登录；登录由原生页完成）。
  static final List<CosMiniProgram> forLauncherGrid = [
    piReimbursementPending,
    piReimbursementApproval,
    stockReconciliation,
    deskHome,
  ];

  static CosMiniProgram? tryFindById(String id) {
    for (final p in forLauncherGrid) {
      if (p.id == id) return p;
    }
    return null;
  }
}
