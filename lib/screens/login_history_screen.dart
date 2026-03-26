import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../auth/cos_auth_service.dart';
import '../auth/cos_login_history_store.dart';
import '../wechat_ui/wechat_colors.dart';

/// 历史登录列表：分组展示，点选回填登录页；左滑删除。
///
/// [fromAccountSwitch] 为 true 时（用户中心「切换账号」进入）：点选凭证会先暂存再 [CosAuthService.logout]，
/// 根路由变为登录页后由 [LoginScreen] 消费暂存并填充；不再向上一页 pop 结果。
class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key, this.fromAccountSwitch = false});

  /// 是否从「切换账号」进入（选凭证即登出并跳转登录页）。
  final bool fromAccountSwitch;

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  List<CosLoginHistoryEntry>? _entries;
  String? _loadError;

  static const List<Color> _avatarColors = [
    Color(0xFFE8A87C),
    Color(0xFF5CADAD),
    Color(0xFFCDB196),
    Color(0xFF7B9EAE),
    Color(0xFFB8A9C9),
    Color(0xFF8FBC8F),
    Color(0xFFD4A574),
  ];

  static const Color _deleteRed = Color(0xFFE53935);
  static const Color _deleteRedBg = Color(0xFFFFEBEE);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loadError = null;
      _entries = null;
    });
    try {
      final list = await CosLoginHistoryStore.instance.loadEntries();
      if (mounted) setState(() => _entries = list);
    } catch (e) {
      if (mounted) {
        setState(() {
          _entries = [];
          _loadError = '加载失败：$e';
        });
      }
    }
  }

  Map<String, List<CosLoginHistoryEntry>> _grouped(
      List<CosLoginHistoryEntry> all) {
    final map = <String, List<CosLoginHistoryEntry>>{};
    for (final e in all) {
      map.putIfAbsent(e.groupLabel, () => []).add(e);
    }
    final keys = map.keys.toList()..sort();
    final ordered = <String, List<CosLoginHistoryEntry>>{};
    for (final k in keys) {
      ordered[k] = map[k]!;
    }
    return ordered;
  }

  Color _colorFor(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _avatarColors[h % _avatarColors.length];
  }

  String _avatarChar(CosLoginHistoryEntry e) {
    final s = (e.displayName ?? e.username).trim();
    if (s.isEmpty) return '?';
    final ch = s.characters.first;
    if (ch.isEmpty) return '?';
    return ch.length == 1 && RegExp(r'[a-zA-Z]').hasMatch(ch)
        ? ch.toUpperCase()
        : ch;
  }

  Future<void> _pick(CosLoginHistoryEntry e) async {
    final pwd = await CosLoginHistoryStore.instance.readPassword(e.id);
    await CosLoginHistoryStore.instance.touchLastUsed(e.id);
    final pick = CosLoginHistoryPick(
      id: e.id,
      originString: e.originString,
      username: e.username,
      password: pwd,
    );
    if (widget.fromAccountSwitch) {
      CosLoginHistoryStore.instance.stagePrefillForNextLoginScreen(pick);
      await CosAuthService.instance.logout();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(pick);
  }

  Future<void> _logoutOnly() async {
    await HapticFeedback.lightImpact();
    await CosAuthService.instance.logout();
  }

  Future<void> _openDeleteConfirmSheet(CosLoginHistoryEntry e) async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    final pad = MediaQuery.paddingOf(context);
    final bottomSafe = pad.bottom;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomSafe),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: WeChatMiniUiColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _deleteRedBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 32,
                      color: _deleteRed,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '移除此账号记录？',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: WeChatMiniUiColors.titleText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '「${e.username}」\n${CosLoginHistoryStore.hostPortLine(e.originString)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: WeChatMiniUiColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '本机保存的密码将一并删除，且无法恢复。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: WeChatMiniUiColors.secondaryText
                          .withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: WeChatMiniUiColors.titleText,
                            side: BorderSide(
                              color: WeChatMiniUiColors.hairline,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: _deleteRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('删除'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (ok != true || !mounted) return;
    await HapticFeedback.mediumImpact();
    await CosLoginHistoryStore.instance.remove(e.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Text('已删除该记录'),
        ),
      );
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeChatMiniUiColors.pageBackground,
      appBar: AppBar(
        title: const Text('历史登录'),
        backgroundColor: WeChatMiniUiColors.navBarBackground,
        foregroundColor: WeChatMiniUiColors.titleText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.fromAccountSwitch)
            TextButton(
              onPressed: _logoutOnly,
              child: Text(
                '仅登出',
                style: TextStyle(
                  color: WeChatMiniUiColors.titleText.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            height: 0.5,
            color: WeChatMiniUiColors.hairline,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: WeChatMiniUiColors.secondaryText),
          ),
        ),
      );
    }
    if (_entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_rounded,
                size: 56,
                color:
                    WeChatMiniUiColors.secondaryText.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 16),
              Text(
                '暂无历史账号',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: WeChatMiniUiColors.titleText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '成功登录后会自动记录服务器与账号，方便下次快速选择。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: WeChatMiniUiColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = _grouped(_entries!);
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WeChatMiniUiColors.secondaryText,
                ),
              ),
            ),
            for (final e in entry.value) ...[
              _HistoryCard(
                key: ValueKey<String>(e.id),
                entry: e,
                avatarColor: _colorFor(e.id),
                avatarChar: _avatarChar(e),
                hostPort: CosLoginHistoryStore.hostPortLine(e.originString),
                onTap: () => _pick(e),
                onRequestDelete: () => _openDeleteConfirmSheet(e),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    super.key,
    required this.entry,
    required this.avatarColor,
    required this.avatarChar,
    required this.hostPort,
    required this.onTap,
    required this.onRequestDelete,
  });

  final CosLoginHistoryEntry entry;
  final Color avatarColor;
  final String avatarChar;
  final String hostPort;
  final VoidCallback onTap;
  final VoidCallback onRequestDelete;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: key,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => onRequestDelete(),
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: '删除',
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor,
                  child: Text(
                    avatarChar,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName ?? entry.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: WeChatMiniUiColors.titleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hostPort,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: WeChatMiniUiColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
