import 'package:flutter/material.dart';

import '../mini_program/cos_mini_program.dart';
import '../screens/mini_program_market_screen.dart';
import '../screens/mini_program_runner_screen.dart';
import 'app_routes.dart';

/// 应用内导航集中入口：原生页走命名路由，Alpha 小程序统一走 WebView 容器。
abstract final class CosNavigation {
  static void openMiniProgram(BuildContext context, CosMiniProgram program) {
    if (!program.programEnabled) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('该小程序已由管理员停用，暂不可打开。')),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => MiniProgramRunnerScreen(program: program),
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
