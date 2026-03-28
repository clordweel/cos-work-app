import 'package:flutter/material.dart';

import '../auth/cos_auth_service.dart';
import '../ui/cos_shell_tokens.dart';

/// 编辑在本应用内展示的个人信息。
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
    final shell = context.cosShell;
    final auth = CosAuthService.instance;
    return Scaffold(
      backgroundColor: shell.pageBackground,
      appBar: AppBar(
        title: const Text('个人信息'),
        backgroundColor: shell.navBarBackground,
        foregroundColor: shell.titleText,
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
          child: Container(height: 0.5, color: shell.hairline),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(title: '账号信息'),
          Material(
            color: shell.navBarBackground,
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
              color: shell.navBarBackground,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                title: const Text('姓名'),
                subtitle: Text(
                  auth.fullName!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _SectionTitle(title: '在本应用的展示'),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(
              labelText: '展示名称（可选）',
              hintText: '可与上方姓名不同，仅本应用可见',
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
            '以上内容仅保存在本设备。',
            style: TextStyle(
              fontSize: 12,
              color: shell.secondaryText.withValues(alpha: 0.9),
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
    final shell = context.cosShell;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
