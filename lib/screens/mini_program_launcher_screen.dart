import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_brand.dart';
import '../routing/cos_navigation.dart';
import '../routing/mini_program_registry.dart';
import '../mini_program/cos_mini_program.dart';
import '../wechat_ui/wechat_colors.dart';

/// 仿微信小程序列表页：浅灰底 + 白顶栏 + 宫格入口。
class MiniProgramLauncherScreen extends StatelessWidget {
  const MiniProgramLauncherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: WeChatMiniUiColors.pageBackground,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WeChatStyleLauncherHeader(
              onUserCenter: () => CosNavigation.openUserCenter(context),
              onSettings: () => CosNavigation.openSettings(context),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '我的小程序',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: WeChatMiniUiColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '各入口共享主站登录（同域名 Cookie）。首次使用可打开「登录」。',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: WeChatMiniUiColors.secondaryText
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.74,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final CosMiniProgram mp =
                              MiniProgramRegistry.forLauncherGrid[index];
                          return _WeChatStylePortalTile(
                            program: mp,
                            onOpen: () => CosNavigation.openMiniProgram(
                              context,
                              mp,
                            ),
                          );
                        },
                        childCount: MiniProgramRegistry.forLauncherGrid.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeChatStyleLauncherHeader extends StatelessWidget {
  const _WeChatStyleLauncherHeader({
    required this.onUserCenter,
    required this.onSettings,
  });

  final VoidCallback onUserCenter;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: WeChatMiniUiColors.navBarBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: top),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Image.asset(
                  'assets/brand/app_icon_source.png',
                  height: 28,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kAppDisplayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: WeChatMiniUiColors.titleText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '用户中心',
                  onPressed: onUserCenter,
                  icon: const Icon(
                    Icons.person_outline_rounded,
                    color: WeChatMiniUiColors.capsuleIcon,
                  ),
                ),
                IconButton(
                  tooltip: '设置',
                  onPressed: onSettings,
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: WeChatMiniUiColors.capsuleIcon,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Container(height: 0.5, color: WeChatMiniUiColors.hairline),
        ],
      ),
    );
  }
}

class _WeChatStylePortalTile extends StatelessWidget {
  const _WeChatStylePortalTile({
    required this.program,
    required this.onOpen,
  });

  final CosMiniProgram program;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final Color bg = program.accentColor ?? const Color(0xFF576B95);
    const Color fg = Colors.white;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(program.icon, color: fg, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            program.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w400,
              color: WeChatMiniUiColors.titleText,
            ),
          ),
        ],
      ),
    );
  }
}
