import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/cos_site_store.dart';
import '../mini_program/cos_market_program.dart';
import '../mini_program/cos_mini_program_catalog.dart';
import '../routing/cos_navigation.dart';
import '../ui/cos_shell_tokens.dart';

/// 应用市场：展示 prod 中「在市场展示」的小程序，支持自选添加/移除。
class MiniProgramMarketScreen extends StatefulWidget {
  const MiniProgramMarketScreen({super.key});

  @override
  State<MiniProgramMarketScreen> createState() => _MiniProgramMarketScreenState();
}

class _MiniProgramMarketScreenState extends State<MiniProgramMarketScreen> {
  String? _actionDoc;
  String? _busyHint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CosMiniProgramCatalog.instance.refreshMarketFromServer();
    });
  }

  Future<void> _runAction(Future<String?> Function() fn) async {
    final err = await fn();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.cosShell;
    return Scaffold(
      backgroundColor: shell.pageBackground,
      appBar: AppBar(
        title: const Text('应用市场'),
        backgroundColor: shell.navBarBackground,
        foregroundColor: shell.titleText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: shell.hairline),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => CosMiniProgramCatalog.instance.refreshMarketFromServer(),
        child: ListenableBuilder(
          listenable: Listenable.merge([
            CosMiniProgramCatalog.instance,
            CosSiteStore.instance,
          ]),
          builder: (context, _) {
            final listShell = context.cosShell;
            final cat = CosMiniProgramCatalog.instance;
            final origin = CosSiteStore.instance.isInitialized
                ? CosSiteStore.instance.origin
                : null;

            if (cat.marketLoading && !cat.marketLoaded) {
              return Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }

            if (cat.marketLastError != null && !cat.marketLoaded) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    cat.marketLastError!,
                    style: TextStyle(
                      color: listShell.secondaryText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => cat.refreshMarketFromServer(),
                    child: const Text('重试'),
                  ),
                ],
              );
            }

            final items = cat.marketPrograms;
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                    child: Text(
                      '当前站点暂无开放中的小程序，或列表尚未同步。\n'
                      '可在 ERP 中为小程序勾选「在市场展示」。',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: listShell.secondaryText,
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (cat.marketLastError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MarketRefreshWarningBanner(
                      message: cat.marketLastError!,
                      shell: listShell,
                    ),
                  ),
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _MarketProgramCard(
                    row: items[i],
                    siteOrigin: origin,
                    actionDoc: _actionDoc,
                    busyHint: _busyHint,
                    onOpen: () async {
                      await CosNavigation.openMiniProgram(
                        context,
                        items[i].program,
                      );
                    },
                    onAdd: items[i].program.serverDocName == null
                        ? null
                        : () {
                            final d = items[i].program.serverDocName!;
                            setState(() {
                              _actionDoc = d;
                              _busyHint = '添加中…';
                            });
                            _runAction(
                              () => CosMiniProgramCatalog.instance
                                  .addUserMiniProgram(d),
                            ).whenComplete(() {
                              if (mounted) {
                                setState(() {
                                  _actionDoc = null;
                                  _busyHint = null;
                                });
                              }
                            });
                          },
                    onRemove: items[i].program.serverDocName == null
                        ? null
                        : () {
                            final d = items[i].program.serverDocName!;
                            setState(() {
                              _actionDoc = d;
                              _busyHint = '移除中…';
                            });
                            _runAction(
                              () => CosMiniProgramCatalog.instance
                                  .removeUserMiniProgram(d),
                            ).whenComplete(() {
                              if (mounted) {
                                setState(() {
                                  _actionDoc = null;
                                  _busyHint = null;
                                });
                              }
                            });
                          },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 列表有数据但刷新失败时的提示条：浅色保持琥珀底，深色用琥珀叠在 surface 上，避免刺眼白底。
class _MarketRefreshWarningBanner extends StatelessWidget {
  const _MarketRefreshWarningBanner({
    required this.message,
    required this.shell,
  });

  final String message;
  final CosShellTokens shell;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = dark
        ? Color.alphaBlend(
            const Color(0xFFFFB74D).withValues(alpha: 0.28),
            shell.navBarBackground,
          )
        : const Color(0xFFFFF3E0);
    final Color fg =
        dark ? const Color(0xFFFFE0B2) : const Color(0xFFE65100);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Color.alphaBlend(
            fg.withValues(alpha: 0.35),
            bg,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '刷新未成功：$message',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketProgramCard extends StatelessWidget {
  const _MarketProgramCard({
    required this.row,
    required this.onOpen,
    this.siteOrigin,
    this.onAdd,
    this.onRemove,
    this.actionDoc,
    this.busyHint,
  });

  final CosMarketProgram row;
  final Uri? siteOrigin;
  final VoidCallback onOpen;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final String? actionDoc;
  final String? busyHint;

  @override
  Widget build(BuildContext context) {
    final shell = context.cosShell;
    final p = row.program;
    final Color bg = p.accentColor ?? const Color(0xFF576B95);
    const Color fg = Colors.white;
    final iconUrl = siteOrigin != null
        ? p.resolvedIconUrl(siteOrigin!)
        : null;

    Widget iconChild;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      iconChild = CachedNetworkImage(
        imageUrl: iconUrl,
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) =>
            Icon(Icons.hourglass_empty_rounded, color: fg, size: 20),
        errorWidget: (_, __, ___) => Icon(
          p.materialIcon ?? Icons.apps_outlined,
          color: fg,
          size: 24,
        ),
      );
    } else {
      iconChild = Icon(
        p.materialIcon ?? Icons.apps_outlined,
        color: fg,
        size: 24,
      );
    }

    final doc = p.serverDocName;
    final busy = doc != null && actionDoc == doc && busyHint != null;

    String statusLine;
    if (!row.inLauncher) {
      statusLine = '未添加到首页';
    } else if (row.userPinned) {
      statusLine = '已在首页 · 自选添加';
    } else {
      statusLine = '已在首页 · 由角色默认提供';
    }

    final cs = Theme.of(context).colorScheme;

    return Material(
      color: shell.navBarBackground,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: shell.hairline.withValues(alpha: 0.65)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox(width: 48, height: 48, child: Center(child: iconChild)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: shell.titleText,
                      ),
                    ),
                    if ((p.subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: shell.secondaryText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      statusLine,
                      style: TextStyle(
                        fontSize: 12,
                        color: shell.secondaryText.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (doc != null)
                busy
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: shell.secondaryText,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!row.inLauncher)
                            TextButton(
                              onPressed: onAdd,
                              child: const Text('添加'),
                            )
                          else if (row.userPinned)
                            TextButton(
                              onPressed: onRemove,
                              style: TextButton.styleFrom(
                                foregroundColor: cs.error,
                              ),
                              child: const Text('移除自选'),
                            )
                          else
                            Text(
                              '—',
                              style: TextStyle(
                                fontSize: 13,
                                color: shell.secondaryText,
                              ),
                            ),
                        ],
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
