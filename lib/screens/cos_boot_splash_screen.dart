import 'package:flutter/material.dart';

import '../config/app_brand.dart';
import '../cos_theme.dart';

/// 冷启动占位：纯色背景、居中图标与底部细进度条（简洁，无装饰阴影）。
class CosBootSplashScreen extends StatefulWidget {
  const CosBootSplashScreen({super.key});

  @override
  State<CosBootSplashScreen> createState() => _CosBootSplashScreenState();
}

class _CosBootSplashScreenState extends State<CosBootSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
    final opacity = Tween<double>(begin: 0.92, end: 1.0).animate(curved);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            FadeTransition(
              opacity: opacity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/brand/app_icon_source.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              kAppDisplayName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: kCosBrandBlue.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '正在启动…',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withValues(alpha: 0.38),
              ),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Color(0x14000000),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
