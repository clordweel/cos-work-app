import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_brand.dart';
import '../auth/cos_auth_service.dart';
import '../auth/cos_biometric_gate.dart';
import '../config/cos_site_config.dart';
import '../config/cos_site_store.dart';
import '../config/cos_theme_mode_store.dart';
import '../ui/cos_shell_tokens.dart';

/// 设置：服务器地址、安全与关于。
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
          content: Text('服务器地址已更新，请重新登录'),
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
      const SnackBar(content: Text('已恢复默认地址，请重新登录')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.cosShell;
    return Scaffold(
      backgroundColor: shell.pageBackground,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: shell.navBarBackground,
        foregroundColor: shell.titleText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: shell.hairline),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _SectionTitle(title: '服务器'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              color: shell.navBarBackground,
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
                      backgroundColor: shell.brandGreen,
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
              '恢复默认地址（${CosSiteConfig.defaultOriginString}）',
              style: TextStyle(
                fontSize: 13,
                color: shell.secondaryText,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              '修改服务器地址将退出当前登录。若填写有误，可通过「恢复默认地址」还原。',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: shell.secondaryText.withValues(alpha: 0.9),
              ),
            ),
          ),
          _SectionTitle(title: '应用'),
          ListenableBuilder(
            listenable: CosThemeModeStore.instance,
            builder: (context, _) {
              final mode = CosThemeModeStore.instance.themeMode;
              final shell = context.cosShell;
              Widget modeRow(String label, ThemeMode value) {
                final sel = mode == value;
                return ListTile(
                  title: Text(label),
                  trailing: sel
                      ? Icon(Icons.check_rounded, color: shell.brandGreen)
                      : null,
                  onTap: () =>
                      CosThemeModeStore.instance.setThemeMode(value),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Material(
                  color: shell.navBarBackground,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      modeRow('跟随系统', ThemeMode.system),
                      const Divider(height: 1),
                      modeRow('浅色', ThemeMode.light),
                      const Divider(height: 1),
                      modeRow('深色', ThemeMode.dark),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '外观设置立即生效，与系统深浅色独立时可单独选择。',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: shell.secondaryText.withValues(alpha: 0.9),
              ),
            ),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final v = snap.data;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Material(
                  color: shell.navBarBackground,
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
                      ? '打开应用时用指纹或面容确认身份'
                      : '请先在系统设置中录入指纹或面容';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Material(
                  color: shell.navBarBackground,
                  borderRadius: BorderRadius.circular(12),
                  child: SwitchListTile(
                    title: const Text(
                      '指纹/面容解锁',
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
              '不会替代登录密码，仅用于打开应用时的快捷验证。',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: shell.secondaryText.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: '关于'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              color: shell.navBarBackground,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '$kAppDisplayName 是企业内部工作台，登录后可使用工作台与各业务应用。',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: shell.titleText,
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
    final shell = context.cosShell;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: shell.secondaryText,
        ),
      ),
    );
  }
}
