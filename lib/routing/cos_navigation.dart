import 'package:flutter/material.dart';

import '../config/cos_site_store.dart';
import '../mini_program/cos_mini_program.dart';
import '../mini_program/cos_mini_program_catalog.dart';
import '../screens/mini_program_market_screen.dart';
import '../screens/mini_program_runner_screen.dart';
import '../screens/shell_network_debug_screen.dart';
import 'app_routes.dart';
import 'mini_program_registry.dart';

/// 应用内导航集中入口：原生页走命名路由，Alpha 小程序统一走 WebView 容器。
abstract final class CosNavigation {
  /// 打开前同步一次宫格，使 Desk 中 `nav_bar_inset_mode` / `show_nav_bar_title` 等变更无需重新登录即可生效。
  static Future<void> openMiniProgram(
    BuildContext context,
    CosMiniProgram program,
  ) async {
    if (!program.programEnabled) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('该小程序已由管理员停用，暂不可打开。')),
      );
      return;
    }
    var p = program;
    if (CosSiteStore.instance.isInitialized) {
      await CosMiniProgramCatalog.instance.refreshFromServer();
      p = CosMiniProgramCatalog.instance.findById(program.id) ?? program;
    }
    if (!context.mounted) return;
    if (!p.programEnabled) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('该小程序已由管理员停用，暂不可打开。')),
      );
      return;
    }
    if (p.id == MiniProgramRegistry.shellNetworkDebug.id) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const ShellNetworkDebugScreen(),
        ),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => MiniProgramRunnerScreen(program: p),
      ),
    );
  }

  static Future<void> openUserCenter(BuildContext context) {
    return Navigator.of(context).pushNamed(AppRoutes.userCenter);
  }

  static Future<void> openSettings(BuildContext context) {
    return Navigator.of(context).pushNamed(AppRoutes.settings);
  }

  static Future<void> openMiniProgramMarket(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const MiniProgramMarketScreen(),
      ),
    );
  }
}
