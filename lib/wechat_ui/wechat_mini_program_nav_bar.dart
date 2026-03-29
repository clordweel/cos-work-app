import 'package:flutter/material.dart';

import '../ui/cos_shell_tokens.dart';
import 'wechat_mini_program_capsule.dart';

/// 仿微信小程序顶部栏：左返回（有栈时）、可选居中标题、右胶囊。
///
/// [immersive] 为 true 时不铺整条实色顶栏，控件叠在 WebView 上。
class WeChatMiniProgramNavBar extends StatelessWidget {
  const WeChatMiniProgramNavBar({
    super.key,
    required this.title,
    required this.showBackChevron,
    required this.onBack,
    required this.onCapsuleMore,
    required this.onCapsuleClose,
    this.immersive = false,
    this.showTitle = true,
  });

  final String title;
  final bool showBackChevron;
  final VoidCallback onBack;
  final VoidCallback onCapsuleMore;
  final VoidCallback onCapsuleClose;

  /// true：透明背景，仅占状态栏 + 44 逻辑高度（配合外层全屏 WebView）。
  final bool immersive;

  /// false：不显示标题（H5 自带导航时由网页展示标题）。
  final bool showTitle;

  static const double barHeight = 44;

  static List<Shadow> _titleShadowsForImmersive() => [
        Shadow(
          color: Colors.white.withValues(alpha: 0.95),
          blurRadius: 6,
          offset: const Offset(0, 0),
        ),
        Shadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 3,
          offset: const Offset(0, 0.5),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final shell = context.cosShell;
    // 全面屏/edge-to-edge 下 padding.top 常为 0，viewPadding 仍为真实状态栏高度
    final top = MediaQuery.of(context).viewPadding.top;

    final titleStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: shell.titleText,
      shadows: immersive ? _titleShadowsForImmersive() : null,
    );

    Widget backSlot;
    if (showBackChevron) {
      final icon = Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 18,
        color: shell.capsuleIcon,
      );
      if (immersive) {
        backSlot = Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(child: icon),
                ),
              ),
            ),
          ),
        );
      } else {
        backSlot = SizedBox(
          width: 44,
          height: barHeight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack,
              child: Center(child: icon),
            ),
          ),
        );
      }
    } else {
      backSlot = SizedBox(width: immersive ? 8 : 44, height: barHeight);
    }

    final Widget bar;
    if (showTitle) {
      bar = SizedBox(
        height: barHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            backSlot,
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: showBackChevron ? 4 : 0,
                  right: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: titleStyle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: shell.capsuleRightMargin),
              child: WeChatMiniProgramCapsule(
                onMore: onCapsuleMore,
                onClose: onCapsuleClose,
              ),
            ),
          ],
        ),
      );
    } else {
      bar = SizedBox(
        height: barHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            backSlot,
            const Spacer(),
            Padding(
              padding: EdgeInsets.only(right: shell.capsuleRightMargin),
              child: WeChatMiniProgramCapsule(
                onMore: onCapsuleMore,
                onClose: onCapsuleClose,
              ),
            ),
          ],
        ),
      );
    }

    if (immersive) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: top),
          bar,
        ],
      );
    }

    return Container(
      color: shell.navBarBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: top),
          bar,
          Container(height: 0.5, color: shell.hairline),
        ],
      ),
    );
  }
}
