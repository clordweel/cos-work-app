import 'package:flutter/material.dart';

import '../config/app_brand.dart';
import '../auth/cos_auth_service.dart';
import '../auth/cos_login_history_store.dart';
import '../config/cos_site_config.dart';
import '../config/cos_site_store.dart';
import '../wechat_ui/wechat_colors.dart';
import '../routing/app_routes.dart';

/// 账号密码登录（原生请求，不内嵌网页登录页）。
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryConsumePendingPrefill();
    });
  }

  /// 用户中心选历史账号并登出后，在此回填表单。
  Future<void> _tryConsumePendingPrefill() async {
    final pick =
        CosLoginHistoryStore.instance.consumePendingPrefillForLoginScreen();
    if (pick == null || !mounted) return;
    await _applyHistoryPick(pick, clearSession: false);
  }

  Future<void> _applyHistoryPick(
    CosLoginHistoryPick pick, {
    required bool clearSession,
  }) async {
    try {
      CosSiteConfig.parseOrigin(pick.originString);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }
    await CosSiteStore.instance.setOrigin(pick.originString);
    if (clearSession) {
      await CosAuthService.instance.clearSessionExpectRelogin();
    }
    await CosLoginHistoryStore.instance.touchLastUsed(pick.id);
    if (!mounted) return;
    setState(() {
      _usr.text = pick.username;
      _pwd.text = pick.password ?? '';
      _error = null;
    });
    if (pick.password == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未能读取已保存的密码，请手动输入')),
      );
    }
  }

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
    // 成功时会 notifyListeners 并换首页，本 State 可能随即 dispose，须先写历史再判断 mounted。
    if (err == null) {
      await CosLoginHistoryStore.instance.recordSuccessfulLogin(
        originString: CosSiteStore.instance.origin.toString(),
        username: u,
        password: p,
        displayName: CosAuthService.instance.fullName,
      );
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = err;
    });
  }

  Future<void> _openLoginHistory() async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.loginHistory,
    );
    if (!mounted) return;
    if (result is! CosLoginHistoryPick) return;
    await _applyHistoryPick(result, clearSession: true);
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
              '使用企业账号登录',
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
                    title: const Text('服务器地址'),
                    subtitle: Text(
                      CosSiteStore.instance.isInitialized
                          ? CosSiteStore.instance.originDisplay
                          : '加载中…',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.history_rounded),
                          tooltip: '历史登录',
                          onPressed: _openLoginHistory,
                          color: WeChatMiniUiColors.secondaryText,
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: WeChatMiniUiColors.secondaryText
                              .withValues(alpha: 0.65),
                        ),
                      ],
                    ),
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
              '登录信息会安全保存在本机，便于您使用工作台与各业务应用。',
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
