import 'dart:async';

import 'package:flutter/material.dart';

import '../config/cos_site_store.dart';
import '../mini_program/cos_mini_program.dart';
import '../mini_program/cos_mini_program_catalog.dart';
import '../screens/mini_program_market_screen.dart';
import '../screens/mini_program_runner_screen.dart';
import '../screens/shell_network_debug_screen.dart';
import 'app_routes.dart';
import 'mini_program_registry.dart';

/// 拉取小程序启动配置超时（秒）。
const int _kMiniProgramLaunchTimeoutSeconds = 45;

/// 应用内导航集中入口：原生页走命名路由，Alpha 小程序统一走 WebView 容器。
abstract final class CosNavigation {
  static bool _miniProgramLaunchInProgress = false;

  /// 打开前按 program_id GET 单条 Desk 配置（`get_mini_program_launch_config`），不依赖宫格缓存。
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

    if (program.id == MiniProgramRegistry.shellNetworkDebug.id) {
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const ShellNetworkDebugScreen(),
        ),
      );
      return;
    }

    if (_miniProgramLaunchInProgress) {
      return;
    }

    if (!CosSiteStore.instance.isInitialized) {
      await _pushRunner(context, program);
      return;
    }

    _miniProgramLaunchInProgress = true;
    try {
      var userCancelled = false;
      /// 代码里主动 [Navigator.pop] 关闭加载窗时也会触发 [PopScope]，若把 didPop 当成用户取消会无法跳转。
      var dialogClosedByApp = false;

      showDialog<void>(
        context: context,
        barrierDismissible: true,
        useRootNavigator: true,
        builder: (dialogContext) {
          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (didPop && !dialogClosedByApp) {
                userCancelled = true;
              }
            },
            child: AlertDialog(
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      userCancelled = true;
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          );
        },
      );

      CosMiniProgram p = program;
      try {
        p = await CosMiniProgramCatalog.instance
            .resolveProgramForOpen(program)
            .timeout(
              const Duration(seconds: _kMiniProgramLaunchTimeoutSeconds),
              onTimeout: () => throw TimeoutException('mini_program_launch'),
            );
      } on TimeoutException {
        if (!userCancelled && context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text('打开超时，请检查网络后重试')),
          );
        }
      } catch (e) {
        if (!userCancelled && context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text('打开失败：$e')),
          );
        }
      } finally {
        if (!userCancelled && context.mounted) {
          final nav = Navigator.of(context, rootNavigator: true);
          if (nav.canPop()) {
            dialogClosedByApp = true;
            nav.pop();
          }
        }
      }

      if (!context.mounted || userCancelled) {
        return;
      }
      if (!p.programEnabled) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('该小程序已由管理员停用，暂不可打开。')),
        );
        return;
      }
      await _pushRunner(context, p);
    } finally {
      _miniProgramLaunchInProgress = false;
    }
  }

  static Future<void> _pushRunner(
    BuildContext context,
    CosMiniProgram p,
  ) async {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
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
