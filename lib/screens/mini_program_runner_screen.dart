import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../auth/cos_auth_service.dart';
import '../auth/cos_web_auth_scope.dart';
import '../config/cos_site_store.dart';
import '../mini_program/cos_mini_program.dart';
import '../mini_program/cos_mini_program_nav_bar_inset_mode.dart';
import '../mini_program/worker_portal_token_bootstrap.dart';
import '../ui/cos_shell_tokens.dart';
import '../wechat_ui/wechat_mini_program_nav_bar.dart';

/// 与 Worker Portal `clientEnv.isCosFlutterShell` 约定一致（须含 `CosWorkApp`）。
const String _kCosWorkWebViewUserAgent =
    'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/120.0.0.0 Mobile Safari/537.36 CosWorkApp/1.0';

/// 单个小程序运行容器：顶栏随 DocType「壳内顶栏占位」变化；加载中为屏中动画。
class MiniProgramRunnerScreen extends StatefulWidget {
  const MiniProgramRunnerScreen({super.key, required this.program});

  final CosMiniProgram program;

  @override
  State<MiniProgramRunnerScreen> createState() =>
      _MiniProgramRunnerScreenState();
}

class _MiniProgramRunnerScreenState extends State<MiniProgramRunnerScreen> {
  late final WebViewController _controller;

  /// Worker Portal：首屏用 JS 写入 `localStorage` 后最多 `reload` 一次（部分 WebView 对 hash 灌 token 不可靠）。
  bool _workerPortalDomReloadDone = false;

  /// 本次进入已用 URL `#cosWorkerPortalToken=` 首跳（与 `main.tsx` 同步写入），无需再 inject+reload。
  bool _workerPortalUsedHashBootstrap = false;

  double _loadProgress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _loadError;

  CosMiniProgram get _p => widget.program;

  static String _insetModeDataAttr(CosMiniProgramNavBarInsetMode m) {
    switch (m) {
      case CosMiniProgramNavBarInsetMode.none:
        return 'none';
      case CosMiniProgramNavBarInsetMode.statusBarOnly:
        return 'status_bar_only';
      case CosMiniProgramNavBarInsetMode.appProvided:
        return 'app_provided';
      case CosMiniProgramNavBarInsetMode.pageCustom:
        return 'page_custom';
    }
  }

  static double _contentPaddingTopPx(
    CosMiniProgramNavBarInsetMode mode,
    double statusBar,
  ) {
    switch (mode) {
      case CosMiniProgramNavBarInsetMode.none:
      case CosMiniProgramNavBarInsetMode.pageCustom:
        return 0;
      case CosMiniProgramNavBarInsetMode.statusBarOnly:
        return statusBar;
      case CosMiniProgramNavBarInsetMode.appProvided:
        return statusBar + WeChatMiniProgramNavBar.barHeight;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() {
              _loadProgress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
            debugPrint('[${_p.id}] Loading: $url');
            if (!mounted) return;
            setState(() {
              _loadError = null;
            });
            Future<void>.microtask(() => _injectShellLayoutCssVars());
          },
          onUrlChange: (UrlChange change) {
            Future<void>.microtask(() async {
              await _syncHistoryState();
            });
          },
          onPageFinished: (String url) async {
            debugPrint('[${_p.id}] Loaded: $url');
            await _injectShellLayoutCssVars();
            await _onWorkerPortalDomInjectIfNeeded(url);
            if (!mounted) return;
            await _syncHistoryState();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[${_p.id}] WebView error: ${error.description}');
            if (!mounted) return;
            setState(() {
              _loadError = error.description;
            });
          },
        ),
      );
    CosWebAuthScope.prepareWebViewController(_controller);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.setUserAgent(_kCosWorkWebViewUserAgent);
      if (!mounted) return;
      await _primeCookiesAndLoad();
    });
  }

  /// 与 H5 约定：`--cos-content-padding-top` 为页面主内容区顶留白；`--cos-status-bar-height` /
  /// `--cos-nav-bar-height` 供页面自定义模式选用。`nav_bar_inset_mode` 由 DocType 配置。
  Future<void> _injectShellLayoutCssVars() async {
    if (!mounted) return;
    final double statusBar = MediaQuery.paddingOf(context).top;
    final double navBarPx = WeChatMiniProgramNavBar.barHeight;
    final double contentPad = _contentPaddingTopPx(_p.navBarInsetMode, statusBar);
    final String modeAttr = _insetModeDataAttr(_p.navBarInsetMode);
    final String js = '''
(function(){
  try {
    var r = document.documentElement;
    r.style.setProperty('--cos-status-bar-height', '${statusBar}px');
    r.style.setProperty('--cos-nav-bar-height', '${navBarPx}px');
    r.style.setProperty('--cos-content-padding-top', '${contentPad}px');
    r.setAttribute('data-cos-shell-inset-mode', '$modeAttr');
  } catch (e) {}
})();''';
    try {
      await _controller.runJavaScript(js);
    } catch (e, st) {
      debugPrint('Shell layout CSS vars 注入失败: $e\n$st');
    }
  }

  Future<void> _primeCookiesAndLoad() async {
    _workerPortalDomReloadDone = false;
    _workerPortalUsedHashBootstrap = false;
    final origin = CosSiteStore.instance.origin;
    final launch = _p.launchUriFor(origin);
    await CosAuthService.instance.ensureWebViewCookiesBeforeBrowse(primePageUrl: launch);
    if (!mounted) return;

    if (_p.authKind == CosMiniProgramAuthKind.workerPortalToken) {
      await CosAuthService.instance.ensureWorkerPortalTokenFresh();
      if (!mounted) return;
      final token = await CosAuthService.instance.readWorkerPortalToken();
      if (token != null && token.isNotEmpty) {
        await _controller.loadRequest(
          WorkerPortalTokenBootstrap.uriWithEmbeddedToken(launch, token),
        );
        _workerPortalUsedHashBootstrap = true;
        return;
      }
      await _controller.loadRequest(launch);
      return;
    }
    await _controller.loadRequest(launch);
  }

  Future<void> _onWorkerPortalDomInjectIfNeeded(String url) async {
    if (_p.authKind != CosMiniProgramAuthKind.workerPortalToken) return;
    if (_workerPortalUsedHashBootstrap) return;
    if (!url.contains('worker-portal')) return;
    if (!CosAuthService.instance.isLoggedIn) return;
    final token = await CosAuthService.instance.readWorkerPortalToken();
    if (token == null || token.isEmpty) return;
    try {
      await _controller.runJavaScript(
        '(function(){try{localStorage.setItem("cos_worker_portal_token",${jsonEncode(token)});}catch(e){}})();',
      );
    } catch (e, st) {
      debugPrint('WorkerPortal localStorage 注入失败: $e\n$st');
    }
    if (!_workerPortalDomReloadDone && mounted) {
      _workerPortalDomReloadDone = true;
      await _controller.reload();
    }
  }

  Future<void> _syncHistoryState() async {
    final back = await _controller.canGoBack();
    final forward = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  Future<void> _onBackOrSystemPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      await _syncHistoryState();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onCapsuleClose() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _goForward() async {
    if (await _controller.canGoForward()) {
      await _controller.goForward();
      await _syncHistoryState();
    }
  }

  Future<void> _reload() async {
    setState(() => _loadError = null);
    await _controller.reload();
  }

  Future<void> _retryFromStart() async {
    if (!mounted) return;
    setState(() => _loadError = null);
    await _primeCookiesAndLoad();
  }

  void _showCapsuleMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  title: const Text(
                    '刷新',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _reload();
                  },
                ),
                if (_canGoForward)
                  ListTile(
                    title: const Text(
                      '前进',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _goForward();
                    },
                  ),
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    '取消',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      color: sheetContext.cosShell.brandGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _showCenterLoading =>
      _loadProgress < 1.0 && _loadError == null;

  @override
  Widget build(BuildContext context) {
    final shell = context.cosShell;
    final topInset = MediaQuery.paddingOf(context).top;
    final double chromeTop =
        topInset + WeChatMiniProgramNavBar.barHeight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _onBackOrSystemPop();
      },
      child: Scaffold(
        backgroundColor: shell.pageBackground,
        body: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),
            if (_showCenterLoading)
              Positioned(
                top: chromeTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.06),
                    child: Center(
                      child: SpinKitRing(
                        color: shell.brandGreen,
                        lineWidth: 3,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WeChatMiniProgramNavBar(
                    immersive: true,
                    showTitle: !_canGoBack,
                    title: _p.title,
                    showBackChevron: _canGoBack,
                    onBack: _onBackOrSystemPop,
                    onCapsuleMore: _showCapsuleMoreMenu,
                    onCapsuleClose: _onCapsuleClose,
                  ),
                  if (_loadError != null)
                    ColoredBox(
                      color: const Color(0xEEFFF4F0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFFFA5151),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _loadError!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xB3000000),
                                  height: 1.3,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 4,
                              children: [
                                TextButton(
                                  onPressed: _reload,
                                  child: const Text('刷新'),
                                ),
                                TextButton(
                                  onPressed: _retryFromStart,
                                  child: const Text('重新进入'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
