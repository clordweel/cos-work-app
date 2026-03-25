import 'package:flutter/material.dart';

import '../config/app_brand.dart';
import '../auth/cos_auth_service.dart';
import '../auth/cos_biometric_gate.dart';
import '../config/cos_site_store.dart';
import '../wechat_ui/wechat_colors.dart';
import '../routing/app_routes.dart';

/// 原生登录（Frappe `/api/method/login`），不加载 Frappe 登录页。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usr = TextEditingController();
  final _pwd = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usr.dispose();
    _pwd.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final u = _usr.text.trim();
    final p = _pwd.text;
    if (u.isEmpty || p.isEmpty) {
      setState(() => _error = '请输入账号与密码');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await CosAuthService.instance.login(usr: u, pwd: p);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = err;
    });
    if (err == null) {
      await _offerBiometricSetupIfNeeded();
    }
  }

  Future<void> _offerBiometricSetupIfNeeded() async {
    if (!mounted) return;
    if (!await CosBiometricGate.isDeviceSupported()) return;
    if (!await CosBiometricGate.hasEnrolledBiometrics()) return;
    if (CosAuthService.instance.biometricGateEnabled) return;
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('启用生物识别解锁？'),
        content: const Text(
          '下次打开应用时，将先通过指纹或面容验证再进入主界面。\n\n'
          '说明：此处使用系统生物识别保护本机已保存的登录会话；'
          'FIDO2 / Passkey 需主站提供 WebAuthn 接口，当前版本未接入。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('启用'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final msg = await CosAuthService.instance.setBiometricGateEnabled(true);
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已开启生物识别解锁')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeChatMiniUiColors.pageBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          children: [
            const SizedBox(height: 12),
            Text(
              kAppDisplayName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: WeChatMiniUiColors.titleText,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '使用主站账号登录',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: WeChatMiniUiColors.secondaryText,
              ),
            ),
            const SizedBox(height: 28),
            ListenableBuilder(
              listenable: CosSiteStore.instance,
              builder: (context, _) {
                return Material(
                  color: WeChatMiniUiColors.navBarBackground,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    title: const Text('站点地址'),
                    subtitle: Text(
                      CosSiteStore.instance.isInitialized
                          ? CosSiteStore.instance.originDisplay
                          : '加载中…',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.settings),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usr,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '邮箱 / 用户名',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pwd,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '密码',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFA5151),
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: WeChatMiniUiColors.brandGreen,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('登录', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            Text(
              '登录成功后，会话将写入本机并与小程序 WebView 共享（同站点 Cookie）。',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: WeChatMiniUiColors.secondaryText.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
