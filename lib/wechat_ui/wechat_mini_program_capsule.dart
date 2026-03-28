import 'package:flutter/material.dart';

import '../ui/cos_shell_tokens.dart';

/// 微信小程序导航栏右侧「胶囊」：··· | 分隔 | ◎（关闭回宿主）。
class WeChatMiniProgramCapsule extends StatelessWidget {
  const WeChatMiniProgramCapsule({
    super.key,
    required this.onMore,
    required this.onClose,
  });

  final VoidCallback onMore;
  final VoidCallback onClose;

  static const double height = 32;

  @override
  Widget build(BuildContext context) {
    final shell = context.cosShell;
    return Container(
      height: height,
      constraints: const BoxConstraints(minWidth: 88),
      decoration: BoxDecoration(
        color: shell.navBarBackground,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: shell.capsuleBorder,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CapsuleHit(
            onTap: onMore,
            child: _CapsuleThreeDots(color: shell.capsuleIcon),
          ),
          Container(
            width: 0.5,
            height: 18,
            color: shell.hairline,
          ),
          _CapsuleHit(
            onTap: onClose,
            child: _WeChatTargetGlyph(color: shell.capsuleIcon),
          ),
        ],
      ),
    );
  }
}

/// 加粗圆点（替代 Material 细线 `more_horiz`）。
class _CapsuleThreeDots extends StatelessWidget {
  const _CapsuleThreeDots({required this.color});

  final Color color;

  static const double _dot = 4.8;
  static const double _gap = 3.8;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Container(
            width: _dot,
            height: _dot,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

class _CapsuleHit extends StatelessWidget {
  const _CapsuleHit({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(WeChatMiniProgramCapsule.height / 2),
        child: SizedBox(
          width: 44,
          height: WeChatMiniProgramCapsule.height,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// 仿微信胶囊右侧「同心圆 / 靶心」图形。
class _WeChatTargetGlyph extends StatelessWidget {
  const _WeChatTargetGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _WeChatTargetPainter(color: color),
      ),
    );
  }
}

class _WeChatTargetPainter extends CustomPainter {
  const _WeChatTargetPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final inner = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.36, outer);
    canvas.drawCircle(center, size.width * 0.12, inner);
  }

  @override
  bool shouldRepaint(covariant _WeChatTargetPainter oldDelegate) =>
      oldDelegate.color != color;
}
