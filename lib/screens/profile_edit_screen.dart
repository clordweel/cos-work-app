import 'package:flutter/material.dart';

import '../auth/cos_auth_service.dart';
import '../wechat_ui/wechat_colors.dart';

/// 原生个人信息（展示名、手机等）；与 Frappe 用户 id 分离，可后续对接同步 API。
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _displayName = TextEditingController();
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    final a = CosAuthService.instance;
    _displayName.text = a.localDisplayName ?? '';
    _phone.text = a.localPhone ?? '';
  }

  @override
  void dispose() {
    _displayName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await CosAuthService.instance.updateLocalProfile(
      displayName: _displayName.text.trim(),
      phone: _phone.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = CosAuthService.instance;
    return Scaffold(
      backgroundColor: WeChatMiniUiColors.pageBackground,
      appBar: AppBar(
        title: const Text('个人信息'),
        backgroundColor: WeChatMiniUiColors.navBarBackground,
        foregroundColor: WeChatMiniUiColors.titleText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: WeChatMiniUiColors.hairline),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(title: '主站账号（只读）'),
          Material(
            color: WeChatMiniUiColors.navBarBackground,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              title: const Text('登录用户'),
              subtitle: Text(
                auth.userId ?? '—',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          if (auth.fullName != null) ...[
            const SizedBox(height: 8),
            Material(
              color: WeChatMiniUiColors.navBarBackground,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                title: const Text('主站姓名'),
                subtitle: Text(
                  auth.fullName!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _SectionTitle(title: '本机展示信息'),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(
              labelText: '展示名称（可选）',
              hintText: '在应用内显示，可与主站姓名不同',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '手机号（可选）',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '以上内容仅存于本设备，后续可通过接口与主站同步。',
            style: TextStyle(
              fontSize: 12,
              color: WeChatMiniUiColors.secondaryText.withValues(alpha: 0.9),
            ),
          ),
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
      padding: const EdgeInsets.only(bottom: 8),
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
