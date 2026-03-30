import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/cos_company_context.dart';
import '../config/cos_site_store.dart';
import '../mini_program/cos_mini_program.dart';
import '../mini_program/cos_mini_program_catalog.dart';
import '../routing/cos_navigation.dart';
import '../ui/cos_shell_tokens.dart';

void _showLauncherProgramManageSheet(
  BuildContext context,
  CosMiniProgram program,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final shell = ctx.cosShell;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                program.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.storefront_outlined,
                color: shell.capsuleIcon,
              ),
              title: const Text('应用市场'),
              subtitle: const Text('浏览站点开放的小程序，添加后显示在首页'),
              onTap: () {
                Navigator.pop(ctx);
                CosNavigation.openMiniProgramMarket(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.sync_outlined,
                color: shell.capsuleIcon,
              ),
              title: const Text('更新配置'),
              subtitle: const Text(
                '从站点重新拉取本入口（顶栏占位、标题等）；并刷新首页宫格列表',
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final err = await CosMiniProgramCatalog.instance
                    .refreshLauncherEntryFromSite(program);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      err ?? '已更新「${program.title}」及宫格配置',
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            if (program.serverDocName == null)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('内置入口'),
                subtitle: const Text(
                  '当前为应用内置列表；连接站点同步后将显示后台配置并支持自选管理。',
                ),
              ),
            if (program.serverDocName != null && !program.programEnabled)
              const ListTile(
                leading: Icon(Icons.block, color: Colors.orange),
                title: Text('管理员已停用'),
                subtitle: Text(
                  '后台取消启用后入口仍保留在首页，但不可打开；恢复启用后将自动可用。',
                ),
              ),
            if (program.serverDocName != null && program.userPinnedOnLauncher)
              ListTile(
                leading: Icon(Icons.remove_circle_outline, color: Colors.red.shade700),
                title: const Text('从首页移除自选'),
                subtitle: const Text(
                  '仅删除您的自选记录；若角色仍分配此小程序，首页可能继续显示。',
                ),
                onTap: () async {
                  final doc = program.serverDocName!;
                  Navigator.pop(ctx);
                  final err = await CosMiniProgramCatalog.instance
                      .removeUserMiniProgram(doc);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err ?? '已从首页移除自选'),
                    ),
                  );
                },
              ),
            if (program.serverDocName != null && !program.userPinnedOnLauncher)
              const ListTile(
                leading: Icon(Icons.group_outlined),
                title: Text('来自角色默认'),
                subtitle: Text(
                  '此入口由管理员按角色分配，无法在应用内移除；请联系管理员调整。',
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// 首页：应用入口宫格。
class MiniProgramLauncherScreen extends StatelessWidget {
  const MiniProgramLauncherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.cosShell;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: shell.pageBackground,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WeChatStyleLauncherHeader(
              onUserCenter: () => CosNavigation.openUserCenter(context),
              onSettings: () => CosNavigation.openSettings(context),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await CosMiniProgramCatalog.instance.refreshFromServer(
                    force: true,
                  );
                  await CosMiniProgramCatalog.instance.refreshMarketFromServer();
                },
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    CosMiniProgramCatalog.instance,
                    CosSiteStore.instance,
                  ]),
                  builder: (context, _) {
                    final tileShell = context.cosShell;
                    final programs =
                        CosMiniProgramCatalog.instance.launcherPrograms;
                    final origin = CosSiteStore.instance.isInitialized
                        ? CosSiteStore.instance.origin
                        : null;
                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                                    color: tileShell.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '长按图标打开管理：可移除自选小程序；在「应用市场」可将小程序添加到首页。下拉同步站点。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: tileShell.secondaryText
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
                                final CosMiniProgram mp = programs[index];
                                return _WeChatStylePortalTile(
                                  program: mp,
                                  siteOrigin: origin,
                                  onOpen: () async {
                                    if (!mp.programEnabled) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '该小程序已由管理员停用，恢复前无法打开。可长按入口进行管理。',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    await CosNavigation.openMiniProgram(
                                      context,
                                      mp,
                                    );
                                  },
                                  onLongPress: () =>
                                      _showLauncherProgramManageSheet(
                                        context,
                                        mp,
                                      ),
                                );
                              },
                              childCount: programs.length,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            child: Material(
                              color: tileShell.navBarBackground,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    CosNavigation.openMiniProgramMarket(context),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.storefront_outlined,
                                        color: tileShell.capsuleIcon,
                                        size: 26,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '应用市场',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: tileShell.titleText,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '浏览站点开放的小程序，自选添加到首页',
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 1.35,
                                                color: tileShell.secondaryText
                                                    .withValues(alpha: 0.9),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: tileShell.secondaryText
                                            .withValues(alpha: 0.65),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    );
                  },
                ),
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
    final shell = context.cosShell;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: shell.navBarBackground,
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
                      if (cc.loading && cc.companies.isEmpty) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '加载公司…',
                            style: TextStyle(
                              fontSize: 14,
                              color: shell.secondaryText,
                            ),
                          ),
                        );
                      }
                      if (cc.companies.isEmpty) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cc.errorMessage ?? '暂无可用公司',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: shell.secondaryText,
                            ),
                          ),
                        );
                      }
                      if (cc.companies.length == 1) {
                        final only = cc.companies.first;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            only.displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: shell.titleText,
                            ),
                          ),
                        );
                      }
                      var value = cc.activeName;
                      if (value != null &&
                          !cc.companies.any((e) => e.name == value)) {
                        value = null;
                      }
                      value ??= cc.companies.first.name;
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: value,
                          icon: Icon(
                            Icons.arrow_drop_down_rounded,
                            color: shell.capsuleIcon,
                          ),
                          dropdownColor: shell.navBarBackground,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: shell.titleText,
                          ),
                          items: cc.companies
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: e.name,
                                  child: Text(
                                    e.displayLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: cc.loading
                              ? null
                              : (v) async {
                                  if (v == null) return;
                                  final err =
                                      await cc.setActiveCompany(v);
                                  if (!context.mounted) return;
                                  if (err != null) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(content: Text(err)),
                                    );
                                  }
                                },
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  tooltip: '用户中心',
                  onPressed: onUserCenter,
                  icon: Icon(
                    Icons.person_outline_rounded,
                    color: shell.capsuleIcon,
                  ),
                ),
                IconButton(
                  tooltip: '设置',
                  onPressed: onSettings,
                  icon: Icon(
                    Icons.settings_outlined,
                    color: shell.capsuleIcon,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Container(height: 0.5, color: shell.hairline),
        ],
      ),
    );
  }
}

class _WeChatStylePortalTile extends StatelessWidget {
  const _WeChatStylePortalTile({
    required this.program,
    required this.onOpen,
    this.onLongPress,
    this.siteOrigin,
  });

  final CosMiniProgram program;
  final VoidCallback onOpen;
  final VoidCallback? onLongPress;
  final Uri? siteOrigin;

  @override
  Widget build(BuildContext context) {
    final shell = context.cosShell;
    final Color bg = program.accentColor ?? const Color(0xFF576B95);
    const Color fg = Colors.white;
    final disabled = !program.programEnabled;
    final iconUrl = siteOrigin != null
        ? program.resolvedIconUrl(siteOrigin!)
        : null;

    Widget iconChild;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      iconChild = CachedNetworkImage(
        imageUrl: iconUrl,
        width: 32,
        height: 32,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) =>
            Icon(Icons.hourglass_empty_rounded, color: fg, size: 24),
        errorWidget: (_, __, ___) => Icon(
          program.materialIcon ?? Icons.apps_outlined,
          color: fg,
          size: 28,
        ),
      );
    } else {
      iconChild = Icon(
        program.materialIcon ?? Icons.apps_outlined,
        color: fg,
        size: 28,
      );
    }

    final tile = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Center(child: iconChild),
              ),
            ),
            if (disabled)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '停用',
                    style: TextStyle(
                      fontSize: 9,
                      height: 1,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          program.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w400,
            color: disabled
                ? shell.secondaryText
                : shell.titleText,
          ),
        ),
      ],
    );

    return InkWell(
      onTap: onOpen,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: tile,
      ),
    );
  }
}
