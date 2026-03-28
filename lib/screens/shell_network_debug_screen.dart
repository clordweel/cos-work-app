import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/cos_auth_service.dart';
import '../auth/cos_company_context.dart';
import '../auth/cos_secure_storage_factory.dart';
import '../auth/cos_session_storage_keys.dart';
import '../auth/frappe_native_session.dart';
import '../config/cos_frappe_api_methods.dart';
import '../config/cos_site_store.dart';
import '../ui/cos_shell_tokens.dart';

/// 壳内调试：站点、会话、Cookie 快照、公司上下文与若干只读 RPC（不输出完整密钥）。
class ShellNetworkDebugScreen extends StatefulWidget {
  const ShellNetworkDebugScreen({super.key});

  @override
  State<ShellNetworkDebugScreen> createState() =>
      _ShellNetworkDebugScreenState();
}

class _ShellNetworkDebugScreenState extends State<ShellNetworkDebugScreen> {
  String _staticLines = '';
  String _rpcLog = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatic();
  }

  Future<void> _refreshStatic() async {
    final buf = StringBuffer();
    buf.writeln('平台: ${Platform.operatingSystem}');
    buf.writeln(
      '站点初始化: ${CosSiteStore.instance.isInitialized ? "是" : "否"}',
    );
    if (CosSiteStore.instance.isInitialized) {
      buf.writeln('站点根: ${CosSiteStore.instance.origin}');
    }
    buf.writeln('壳已登录(isLoggedIn): ${CosAuthService.instance.isLoggedIn}');
    buf.writeln('userId: ${CosAuthService.instance.userId ?? "（无）"}');

    final sid = await cosFlutterSecureStorage.read(key: CosSessionKeys.frappeSid);
    buf.writeln('sid: ${_mask(sid)}');

    final wpt = await CosAuthService.instance.readWorkerPortalToken();
    buf.writeln('Worker Portal token: ${_maskWpt(wpt)}');

    final prefs = await SharedPreferences.getInstance();
    final rawCookies = prefs.getString(CosSessionKeys.frappeWebCookiesJson);
    if (rawCookies == null || rawCookies.isEmpty) {
      buf.writeln('Frappe Cookie 快照: （无）');
    } else {
      buf.writeln(
        'Frappe Cookie 快照: 已存，约 ${rawCookies.length} 字符',
      );
    }

    final cc = CosCompanyContext.instance;
    buf.writeln(
      '当前公司: ${cc.activeDisplayLabel ?? cc.activeName ?? "（未拉取/无）"}',
    );
    buf.writeln('公司列表条数: ${cc.companies.length}');

    if (mounted) {
      setState(() => _staticLines = buf.toString().trim());
    }
  }

  static String _mask(String? s) {
    if (s == null || s.isEmpty) return '（无）';
    if (s.length <= 6) return '****（${s.length} 字符）';
    return '${s.substring(0, 2)}…${s.substring(s.length - 3)}（${s.length}）';
  }

  static String _maskWpt(String? s) {
    if (s == null || s.isEmpty) return '（无）';
    final p = s.startsWith('wpt.') ? 'wpt.*' : '（非 wpt 前缀）';
    return '$p 长度 ${s.length}';
  }

  Future<List<Cookie>> _sessionCookies() async {
    if (!CosSiteStore.instance.isInitialized) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(CosSessionKeys.frappeWebCookiesJson);
    final sid = await cosFlutterSecureStorage.read(key: CosSessionKeys.frappeSid);
    final host = CosSiteStore.instance.origin.host;
    return FrappeNativeSession.cookiesFromPersistedJson(
      frappeCookiesJson: raw,
      host: host,
      sidValue: sid,
    );
  }

  Future<void> _runRpc(String label, Future<String> Function() fn) async {
    setState(() {
      _busy = true;
      _rpcLog = '执行 $label…';
    });
    try {
      final out = await fn();
      if (mounted) {
        setState(() => _rpcLog = '$label\n$out');
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _rpcLog = '$label\n异常: $e\n$st');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _rpcGetLoggedUser() async {
    final origin = CosSiteStore.instance.origin;
    final cookies = await _sessionCookies();
    if (cookies.isEmpty) {
      return '跳过：无可用 Cookie/sid';
    }
    final u = await FrappeNativeSession.getLoggedUser(
      siteOrigin: origin,
      cookies: cookies,
    );
    return 'get_logged_user → ${u ?? "（null）"}';
  }

  Future<String> _rpcIssueWpt() async {
    final origin = CosSiteStore.instance.origin;
    final cookies = await _sessionCookies();
    if (cookies.isEmpty) {
      return '跳过：无可用 Cookie/sid';
    }
    final res = await FrappeNativeSession.callMethodGet(
      siteOrigin: origin,
      cookies: cookies,
      dottedMethod: CosFrappeApiMethods.issueWorkerPortalTokenFromSession,
      invalidateSessionOnAuthFailure: false,
    );
    if (!res.ok) {
      return 'issue_token_from_session 失败: ${res.errorText}';
    }
    final msg = res.message;
    if (msg is Map && msg['token'] is String) {
      final t = msg['token'] as String;
      return 'issue_token_from_session OK，token: ${_maskWpt(t)}';
    }
    return 'issue_token_from_session 响应: $msg';
  }

  Future<String> _rpcPingStyleList() async {
    final origin = CosSiteStore.instance.origin;
    final cookies = await _sessionCookies();
    if (cookies.isEmpty) {
      return '跳过：无可用 Cookie/sid';
    }
    final res = await FrappeNativeSession.callMethodGet(
      siteOrigin: origin,
      cookies: cookies,
      dottedMethod: CosFrappeApiMethods.getLauncherPrograms,
      invalidateSessionOnAuthFailure: false,
    );
    if (!res.ok) {
      return 'get_launcher_programs 失败: ${res.errorText}';
    }
    final msg = res.message;
    if (msg is List) {
      return 'get_launcher_programs OK，条数: ${msg.length}';
    }
    return 'get_launcher_programs 响应类型: ${msg.runtimeType}';
  }

  Future<void> _copyAll() async {
    final text = '$_staticLines\n\n--- RPC ---\n$_rpcLog';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.cosShell;
    return Scaffold(
      backgroundColor: shell.pageBackground,
      appBar: AppBar(
        title: const Text('网络与认证调试'),
        backgroundColor: shell.navBarBackground,
        foregroundColor: shell.titleText,
        actions: [
          IconButton(
            tooltip: '刷新静态信息',
            onPressed: _busy ? null : _refreshStatic,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '复制全部',
            onPressed: _copyAll,
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '以下为只读诊断信息，便于对照 WebView / 接口行为；不含完整 sid、wpt。',
            style: TextStyle(fontSize: 13, color: shell.secondaryText),
          ),
          const SizedBox(height: 12),
          SelectableText(
            _staticLines.isEmpty ? '加载中…' : _staticLines,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: shell.titleText,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 20),
          Text('RPC 探测', style: TextStyle(fontWeight: FontWeight.w600, color: shell.titleText)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy || !CosSiteStore.instance.isInitialized
                    ? null
                    : () => _runRpc('get_logged_user', _rpcGetLoggedUser),
                child: const Text('get_logged_user'),
              ),
              FilledButton.tonal(
                onPressed: _busy || !CosSiteStore.instance.isInitialized
                    ? null
                    : () => _runRpc('issue_token_from_session', _rpcIssueWpt),
                child: const Text('issue_token (wpt)'),
              ),
              FilledButton.tonal(
                onPressed: _busy || !CosSiteStore.instance.isInitialized
                    ? null
                    : () => _runRpc('get_launcher_programs', _rpcPingStyleList),
                child: const Text('get_launcher_programs'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            _rpcLog.isEmpty ? '（尚未执行 RPC）' : _rpcLog,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: shell.secondaryText,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
