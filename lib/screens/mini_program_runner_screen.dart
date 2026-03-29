import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../auth/cos_auth_service.dart';
import '../auth/cos_web_auth_scope.dart';
import '../config/cos_site_store.dart';
import '../mini_program/cos_mini_program.dart';
import '../mini_program/cos_mini_program_nav_bar_inset_mode.dart';
import '../ui/cos_shell_tokens.dart';
import '../wechat_ui/wechat_mini_program_nav_bar.dart';

/// 与 Worker Portal `clientEnv.isCosFlutterShell` 约定一致（须含 `CosWorkApp`）。
const String _kCosWorkWebViewUserAgent =
    'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/120.0.0.0 Mobile Safari/537.36 CosWorkApp/1.0';

/// 单个小程序运行容器；顶栏占位以站点模板 + `cos_work_shell_inset.css` 为主，首跳带 `__cos_work_shell=1`；
/// 若服务端仍未打上壳标记则按 [CosMiniProgram.navBarInsetMode] 回退注入 CSS 变量。
class MiniProgramRunnerScreen extends StatefulWidget {
  const MiniProgramRunnerScreen({super.key, required this.program});

  final CosMiniProgram program;

  @override
  State<MiniProgramRunnerScreen> createState() =>
      _MiniProgramRunnerScreenState();
}

class _MiniProgramRunnerScreenState extends State<MiniProgramRunnerScreen> {
  late final WebViewController _controller;

  double _loadProgress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _loadError;

  CosMiniProgram get _p => widget.program;

  static String _shellInsetModeAttr(CosMiniProgramNavBarInsetMode m) {
    return switch (m) {
      CosMiniProgramNavBarInsetMode.none => 'none',
      CosMiniProgramNavBarInsetMode.statusBar => 'status_bar',
      CosMiniProgramNavBarInsetMode.appBar => 'app_bar',
    };
  }

  static double _shellContentPaddingTopPx(
    CosMiniProgramNavBarInsetMode mode,
    double statusBar,
    double navBarPx,
  ) {
    return switch (mode) {
      CosMiniProgramNavBarInsetMode.none => 0,
      // WebView 已从系统状态栏下沿起算，H5 只需避让叠在上面的 44px 顶栏
      CosMiniProgramNavBarInsetMode.statusBar => navBarPx,
      CosMiniProgramNavBarInsetMode.appBar => statusBar + navBarPx,
    };
  }

  /// status_bar：WebView 顶对齐系统状态栏下沿，全屏叠在下的 44px 顶栏由 H5 用 --cos-content-padding-top 避让。
  double _webViewTopPx(double topInset) {
    return switch (_p.navBarInsetMode) {
      CosMiniProgramNavBarInsetMode.statusBar => topInset,
      _ => 0,
    };
  }

  /// 部分 WebView 首请求无 CosWorkApp UA 时模板不输出壳样式；仅在未检测到服务端已标记时补变量。
  Future<void> _applyShellInsetFallbackIfServerSkipped() async {
    if (!mounted) return;
    final statusBar = MediaQuery.of(context).viewPadding.top;
    final navBarPx = WeChatMiniProgramNavBar.barHeight;
    final modeStr = _shellInsetModeAttr(_p.navBarInsetMode);
    final contentPad =
        _shellContentPaddingTopPx(_p.navBarInsetMode, statusBar, navBarPx);
    final js = '''
(function(){
  try {
    var r = document.documentElement;
    if (r.getAttribute('data-cos-work-app-shell') === '1') return;
    r.setAttribute('data-cos-work-app-shell','1');
    r.setAttribute('data-cos-shell-inset-mode','$modeStr');
    r.style.setProperty('--cos-status-bar-height', '${statusBar}px');
    r.style.setProperty('--cos-nav-bar-height', '${navBarPx}px');
    r.style.setProperty('--cos-content-padding-top', '${contentPad}px');
  } catch (e) {}
})();''';
    try {
      await _controller.runJavaScript(js);
    } catch (e, st) {
      debugPrint('壳顶栏占位回退注入失败: $e\n$st');
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
          },
          onUrlChange: (UrlChange change) {
            Future<void>.microtask(() async {
              await _syncHistoryState();
            });
          },
          onPageFinished: (String url) async {
            debugPrint('[${_p.id}] Loaded: $url');
            if (!mounted) return;
            await _syncHistoryState();
            await _applyShellInsetFallbackIfServerSkipped();
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

  Future<void> _primeCookiesAndLoad() async {
    final origin = CosSiteStore.instance.origin;
    final launch = _p.launchUriFor(origin);
    await CosAuthService.instance.ensureWebViewCookiesBeforeBrowse(primePageUrl: launch);
    if (!mounted) return;
    await _controller.loadRequest(launch);
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
    // 与 WeChatMiniProgramNavBar 一致：用 viewPadding 适配全面屏 edge-to-edge
    final topInset = MediaQuery.of(context).viewPadding.top;
    final webTop = _webViewTopPx(topInset);

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
            Positioned(
              top: webTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: WebViewWidget(controller: _controller),
            ),
            if (_showCenterLoading)
              Positioned(
                top: webTop,
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
                    showTitle: _p.showNavBarTitle && !_canGoBack,
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
