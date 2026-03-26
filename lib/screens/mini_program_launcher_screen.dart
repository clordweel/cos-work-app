import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/cos_auth_service.dart';
import '../auth/cos_biometric_gate.dart';
import '../auth/cos_company_context.dart';
import '../config/app_brand.dart';
import '../routing/cos_navigation.dart';
import '../routing/mini_program_registry.dart';
import '../mini_program/cos_mini_program.dart';
import '../wechat_ui/wechat_colors.dart';

/// 首页：应用入口宫格。
class MiniProgramLauncherScreen extends StatefulWidget {
  const MiniProgramLauncherScreen({super.key});

  @override
  State<MiniProgramLauncherScreen> createState() =>
      _MiniProgramLauncherScreenState();
}

class _MiniProgramLauncherScreenState extends State<MiniProgramLauncherScreen> {
  bool _postLoginBiometricScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schedulePostLoginBiometricOffer();
    });
  }

  /// 登录成功后 [CosAuthService] 会置位；在此用稳定 context 弹窗，并在关闭 Material 对话框后再调系统生物识别。
  Future<void> _schedulePostLoginBiometricOffer() async {
    if (_postLoginBiometricScheduled) return;
    if (!CosAuthService.instance.hasBiometricLoginOfferPending) return;
    _postLoginBiometricScheduled = true;

    if (!await CosBiometricGate.isDeviceSupported()) {
      CosAuthService.instance.clearBiometricLoginOffer();
      return;
    }
    if (!await CosBiometricGate.hasEnrolledBiometrics()) {
      CosAuthService.instance.clearBiometricLoginOffer();
      return;
    }
    if (CosAuthService.instance.biometricGateEnabled) {
      CosAuthService.instance.clearBiometricLoginOffer();
      return;
    }
    if (!mounted) {
      CosAuthService.instance.clearBiometricLoginOffer();
      return;
    }

    CosAuthService.instance.clearBiometricLoginOffer();

    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('启用指纹或面容解锁？'),
        content: const Text(
          '下次打开应用时，可先验证指纹或面容再进入，无需重复输入密码。\n\n'
          '说明：用于保护本机已登录状态，不会代替您的登录密码。',
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

    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;

    final msg = await CosAuthService.instance.setBiometricGateEnabled(true);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    if (msg != null) {
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('已开启指纹/面容解锁')),
      );
    }
  }

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
                            '应用',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: WeChatMiniUiColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '点击下方图标进入对应功能。若提示登录，请先在登录页完成验证。',
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
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 12),
                Image.asset(
                  'assets/brand/app_icon_source.png',
                  height: 28,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ListenableBuilder(
                    listenable: CosCompanyContext.instance,
                    builder: (context, _) {
                      final cc = CosCompanyContext.instance;
                      final sub = cc.activeDisplayLabel;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kAppDisplayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: WeChatMiniUiColors.titleText,
                            ),
                          ),
                          if (sub != null)
                            Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: WeChatMiniUiColors.secondaryText
                                    .withValues(alpha: 0.95),
                              ),
                            ),
                        ],
                      );
                    },
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
