import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/cos_auth_service.dart';
import '../auth/cos_company_context.dart';
import '../routing/app_routes.dart';
import '../routing/cos_navigation.dart';
import '../routing/mini_program_registry.dart';
import '../wechat_ui/wechat_colors.dart';

/// 原生用户中心：个人信息、Desk（Web 小程序）、切换账号（原生登出）。
class UserCenterScreen extends StatelessWidget {
  const UserCenterScreen({super.key});

  Future<void> _pickCompany(BuildContext context) async {
    final ctx = CosCompanyContext.instance;
    if (ctx.loading) return;
    if (ctx.companies.isEmpty) {
      await ctx.refreshFromServer();
      if (!context.mounted) return;
      if (ctx.companies.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ctx.errorMessage ?? '暂无可选账套，请确认站点已部署 cos.company_context_api'),
          ),
        );
      }
      return;
    }
    if (ctx.companies.length == 1) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前仅有一个可用账套')),
        );
      }
      return;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  '选择账套（公司）',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              for (final row in ctx.companies)
                ListTile(
                  title: Text(row.displayLabel),
                  subtitle: Text(row.name, style: const TextStyle(fontSize: 12)),
                  trailing: row.name == ctx.activeName
                      ? Icon(Icons.check_circle, color: WeChatMiniUiColors.brandGreen)
                      : null,
                  onTap: () => Navigator.pop(sheetCtx, row.name),
                ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !context.mounted) return;
    if (chosen == ctx.activeName) return;
    final err = await ctx.setActiveCompany(chosen);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已切换账套；小程序内请下拉刷新以同步数据')),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('切换账号'),
        content: const Text('将登出当前账号并清除本机会话，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('登出'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await CosAuthService.instance.logout();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeChatMiniUiColors.pageBackground,
      appBar: AppBar(
        title: const Text('用户中心'),
        backgroundColor: WeChatMiniUiColors.navBarBackground,
        foregroundColor: WeChatMiniUiColors.titleText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: WeChatMiniUiColors.hairline),
        ),
      ),
      body: ListenableBuilder(
        listenable: CosAuthService.instance,
        builder: (context, _) {
          final auth = CosAuthService.instance;
          return ListView(
            children: [
              const SizedBox(height: 12),
              _ProfileCard(
                title: auth.localDisplayName?.isNotEmpty == true
                    ? auth.localDisplayName!
                    : (auth.fullName ?? auth.userId ?? '已登录'),
                subtitle: _profileSubtitle(auth),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.profileEdit),
              ),
              const SizedBox(height: 16),
              _SectionTitle(title: '账套'),
              ListenableBuilder(
                listenable: CosCompanyContext.instance,
                builder: (context, _) {
                  final cc = CosCompanyContext.instance;
                  final subtitle = cc.loading
                      ? '同步中…'
                      : cc.errorMessage != null
                          ? cc.errorMessage!
                          : (cc.activeDisplayLabel != null
                              ? '当前：${cc.activeDisplayLabel}'
                              : (cc.companies.isEmpty
                                  ? '登录后自动加载'
                                  : '未设置默认公司'));
                  return _NativeTile(
                    icon: Icons.apartment_outlined,
                    title: '切换账套',
                    subtitle: subtitle,
                    onTap: cc.loading ? null : () => _pickCompany(context),
                  );
                },
              ),
              const SizedBox(height: 16),
              _SectionTitle(title: '账号'),
              _NativeTile(
                icon: Icons.edit_outlined,
                title: '个人信息',
                subtitle: '本机展示名、手机号等（非 Frappe 网页）',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.profileEdit),
              ),
              _NativeTile(
                icon: Icons.dashboard_outlined,
                title: '打开 Desk',
                subtitle: 'Frappe 工作台（Web 小程序）',
                onTap: () => CosNavigation.openMiniProgram(
                  context,
                  MiniProgramRegistry.deskHome,
                ),
              ),
              _NativeTile(
                icon: Icons.swap_horiz_rounded,
                title: '切换账号',
                subtitle: '登出后使用原生登录页重新登录',
                onTap: () => _confirmLogout(context),
              ),
              const SizedBox(height: 16),
              _SectionTitle(title: '关于本机'),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) {
                  final v = snap.data;
                  return _NativeTile(
                    icon: Icons.info_outline_rounded,
                    title: '应用版本',
                    subtitle:
                        v == null ? '读取中…' : '${v.version} (${v.buildNumber})',
                    onTap: null,
                  );
                },
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '登录与会话由应用原生完成；业务功能仍通过已注册的小程序加载主站页面。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: WeChatMiniUiColors.secondaryText.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _profileSubtitle(CosAuthService auth) {
    final parts = <String>[];
    if (auth.userId != null && auth.userId!.isNotEmpty) {
      parts.add(auth.userId!);
    }
    if (auth.localPhone != null && auth.localPhone!.isNotEmpty) {
      parts.add(auth.localPhone!);
    }
    if (parts.isEmpty) return '点击编辑个人信息';
    return parts.join(' · ');
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: WeChatMiniUiColors.navBarBackground,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: WeChatMiniUiColors.pageBackground,
                  child: Icon(
                    Icons.person_rounded,
                    size: 32,
                    color: WeChatMiniUiColors.secondaryText,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: WeChatMiniUiColors.titleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: WeChatMiniUiColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: WeChatMiniUiColors.secondaryText,
                ),
              ],
            ),
          ),
        ),
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

class _NativeTile extends StatelessWidget {
  const _NativeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: WeChatMiniUiColors.navBarBackground,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: WeChatMiniUiColors.capsuleIcon),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: WeChatMiniUiColors.titleText,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: WeChatMiniUiColors.secondaryText.withValues(alpha: 0.95),
            ),
          ),
          trailing: onTap != null
              ? Icon(
                  Icons.chevron_right_rounded,
                  color: WeChatMiniUiColors.secondaryText,
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
