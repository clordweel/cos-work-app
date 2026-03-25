import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:cos_work_app/cos_theme.dart';
import 'package:cos_work_app/main.dart';
import 'package:cos_work_app/config/cos_site_store.dart';
import 'package:cos_work_app/auth/cos_auth_service.dart';
import 'package:cos_work_app/screens/mini_program_launcher_screen.dart';

import 'webview_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  setUp(() {
    WebViewPlatform.instance = FakeWebViewPlatformForTest();
  });

  testWidgets('启动器呈现「我的小程序」', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await CosSiteStore.instance.init();
    CosAuthService.instance.testingForceAuthenticated();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCosWorkTheme(),
        home: const MiniProgramLauncherScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的小程序'), findsOneWidget);
  });

  testWidgets('CosWorkApp bootstrap 后未登录显示登录页', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const CosWorkApp());
    await tester.pump();

    // 启动页为 CircularProgressIndicator，pumpAndSettle 会因无限动画超时。
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('登录').evaluate().isNotEmpty) break;
    }

    expect(find.text('登录'), findsOneWidget);
  });
}
