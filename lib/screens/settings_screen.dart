import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_brand.dart';
import '../auth/cos_auth_service.dart';
import '../auth/cos_biometric_gate.dart';
import '../config/cos_site_config.dart';
import '../config/cos_site_store.dart';
import '../wechat_ui/wechat_colors.dart';

/// 原生设置：可编辑站点根地址（保存后需重新登录）。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _originCtrl;
  bool _bioCapable = false;
  bool _bioCapsLoaded = false;

  @override
  void initState() {
    super.initState();
    _refreshBioCaps();
    _originCtrl = TextEditingController(
      text: CosSiteStore.instance.isInitialized
          ? CosSiteStore.instance.originDisplay
          : CosSiteConfig.defaultOriginString,
    );
  }

  Future<void> _refreshBioCaps() async {
    final supported = await CosBiometricGate.isDeviceSupported();
    final enrolled = await CosBiometricGate.hasEnrolledBiometrics();
    if (!mounted) return;
    setState(() {
      _bioCapable = supported && enrolled;
      _bioCapsLoaded = true;
    });
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyOrigin() async {
    await Clipboard.setData(ClipboardData(text: _originCtrl.text.trim()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制')),
      );
    }
  }

  Future<void> _saveOrigin() async {
    final raw = _originCtrl.text.trim();
    try {
      CosSiteConfig.parseOrigin(raw);
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    }
    await CosSiteStore.instance.setOrigin(raw);
    await CosAuthService.instance.clearSessionExpectRelogin();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('站点已更新，请重新登录'),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _resetToDefault() async {
    await CosSiteStore.instance.clearSavedOrigin();
    if (!mounted) return;
    _originCtrl.text = CosSiteStore.instance.originDisplay;
    await CosAuthService.instance.clearSessionExpectRelogin();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已恢复默认站点，请重新登录')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeChatMiniUiColors.pageBackground,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: WeChatMiniUiColors.navBarBackground,
        foregroundColor: WeChatMiniUiColors.titleText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: WeChatMiniUiColors.hairline),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _SectionTitle(title: '站点'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              color: WeChatMiniUiColors.navBarBackground,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: TextField(
                  controller: _originCtrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'https://your-site.example',
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _copyOrigin,
                    child: const Text('复制'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saveOrigin,
                    style: FilledButton.styleFrom(
                      backgroundColor: WeChatMiniUiColors.brandGreen,
                    ),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _resetToDefault,
            child: Text(
              '恢复编译默认值（${CosSiteConfig.defaultOriginString}）',
              style: TextStyle(
                fontSize: 13,
                color: WeChatMiniUiColors.secondaryText,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              '修改站点会清除当前登录态。未保存的覆盖仍可通过「恢复默认」使用 --dart-define=COS_SITE_ORIGIN。',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: WeChatMiniUiColors.secondaryText.withValues(alpha: 0.9),
              ),
            ),
          ),
          _SectionTitle(title: '应用'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final v = snap.data;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Material(
                  color: WeChatMiniUiColors.navBarBackground,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    title: const Text(
                      '版本信息',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      v == null
                          ? '读取中…'
                          : '${v.appName} ${v.version} (${v.buildNumber})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: '安全'),
          ListenableBuilder(
            listenable: CosAuthService.instance,
            builder: (context, _) {
              final auth = CosAuthService.instance;
              final subtitle = !_bioCapsLoaded
                  ? '检测中…'
                  : _bioCapable
                      ? '使用系统指纹、面容等验证后进入主界面'
                      : '当前设备不支持或未录入指纹 / 面容';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Material(
                  color: WeChatMiniUiColors.navBarBackground,
                  borderRadius: BorderRadius.circular(12),
                  child: SwitchListTile(
                    title: const Text(
                      '生物识别解锁',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13),
                    ),
                    value: auth.biometricGateEnabled,
                    onChanged: !_bioCapsLoaded
                        ? null
                        : _bioCapable
                            ? (v) async {
                                if (v) {
                                  final msg =
                                      await auth.setBiometricGateEnabled(true);
                                  if (context.mounted && msg != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  }
                                } else {
                                  await auth.setBiometricGateEnabled(false);
                                }
                              }
                            : null,
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '非 FIDO Passkey：不替代主站密码，仅保护本机会话。',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: WeChatMiniUiColors.secondaryText.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: '关于'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              color: WeChatMiniUiColors.navBarBackground,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '$kAppDisplayName：原生负责登录、站点与用户资料壳层；业务小程序加载主站 Frappe 页面。',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: WeChatMiniUiColors.titleText,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: WeChatMiniUiColors.secondaryText,
        ),
      ),
    );
  }
}
