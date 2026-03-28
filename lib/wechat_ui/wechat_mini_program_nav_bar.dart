import 'package:flutter/material.dart';

import '../ui/cos_shell_tokens.dart';
import 'wechat_mini_program_capsule.dart';

/// 仿微信小程序顶部栏：左返回（有栈时）、居中标题、右胶囊。
class WeChatMiniProgramNavBar extends StatelessWidget {
  const WeChatMiniProgramNavBar({
    super.key,
    required this.title,
    required this.showBackChevron,
    required this.onBack,
    required this.onCapsuleMore,
    required this.onCapsuleClose,
  });

  final String title;
  final bool showBackChevron;
  final VoidCallback onBack;
  final VoidCallback onCapsuleMore;
  final VoidCallback onCapsuleClose;

  static const double barHeight = 44;

  @override
  Widget build(BuildContext context) {
    final shell = context.cosShell;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: shell.navBarBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: top),
          SizedBox(
            height: barHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: shell.navBarTitleHorizontalPadding,
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      color: shell.titleText,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      height: barHeight,
                      child: showBackChevron
                          ? Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onBack,
                                child: Center(
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                    color: shell.capsuleIcon,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
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
              ],
            ),
          ),
          Container(height: 0.5, color: shell.hairline),
        ],
      ),
    );
  }
}
