import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_brand.dart';
import 'auth/cos_auth_service.dart';
import 'config/cos_site_store.dart';
import 'cos_theme.dart';
import 'routing/app_routes.dart';
import 'screens/biometric_gate_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mini_program_launcher_screen.dart';
import 'screens/profile_edit_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/user_center_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  runApp(const CosWorkApp());
}

class CosWorkApp extends StatefulWidget {
  const CosWorkApp({super.key});

  @override
  State<CosWorkApp> createState() => _CosWorkAppState();
}

class _CosWorkAppState extends State<CosWorkApp> {
  /// 本 App 实例是否已完成首轮 init（避免单测/热重载时误用其它用例留下的全局状态）。
  bool _bootComplete = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await CosSiteStore.instance.init();
    await CosAuthService.instance.bootstrap();
    if (mounted) setState(() => _bootComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootComplete) {
      return MaterialApp(
        title: kAppDisplayName,
        theme: buildCosWorkTheme(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final auth = CosAuthService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([auth, CosSiteStore.instance]),
      builder: (context, _) {
        return MaterialApp(
          title: kAppDisplayName,
          theme: buildCosWorkTheme(),
          home: !auth.isLoggedIn
              ? const LoginScreen()
              : auth.needsBiometricUnlock
                  ? const BiometricGateScreen()
                  : const MiniProgramLauncherScreen(),
          routes: {
            AppRoutes.settings: (_) => const SettingsScreen(),
            AppRoutes.userCenter: (_) => const UserCenterScreen(),
            AppRoutes.profileEdit: (_) => const ProfileEditScreen(),
          },
        );
      },
    );
  }
}
