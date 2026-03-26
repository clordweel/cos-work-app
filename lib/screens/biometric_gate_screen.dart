import 'package:flutter/material.dart';

import '../auth/cos_auth_service.dart';
import '../config/app_brand.dart';
import '../wechat_ui/wechat_colors.dart';

/// 冷启动：已恢复会话且开启生物识别时，先在此页验证机主身份。
class BiometricGateScreen extends StatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen> {
  bool _busy = false;
  String? _hint;

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _hint = null;
    });
    final ok = await CosAuthService.instance.unlockWithBiometric();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _hint = '验证失败或已取消，请重试');
    }
  }

  Future<void> _logoutToPassword() async {
    await CosAuthService.instance.logout();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeChatMiniUiColors.pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Icon(
                Icons.fingerprint_rounded,
                size: 72,
                color: WeChatMiniUiColors.brandGreen,
              ),
              const SizedBox(height: 20),
              Text(
                kAppDisplayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: WeChatMiniUiColors.titleText,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                '请使用指纹或面容验证身份',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: WeChatMiniUiColors.secondaryText,
                ),
              ),
              if (_hint != null) ...[
                const SizedBox(height: 16),
                Text(
                  _hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFA5151),
                    fontSize: 14,
                  ),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _unlock,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: WeChatMiniUiColors.brandGreen,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('再次验证'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _logoutToPassword,
                child: const Text('改用密码重新登录'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
