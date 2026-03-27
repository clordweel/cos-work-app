import 'cos_mini_program.dart';

/// 市场列表单项：`get_market_programs` 解析结果。
class CosMarketProgram {
  CosMarketProgram({
    required this.program,
    required this.inLauncher,
    required this.userPinned,
  });

  final CosMiniProgram program;
  final bool inLauncher;
  final bool userPinned;

  static bool _truthy(dynamic v) {
    if (v == true) return true;
    if (v == 1 || v == '1') return true;
    return false;
  }

  factory CosMarketProgram.fromPayload(
    Map<String, dynamic> m,
    Uri siteOrigin,
  ) {
    final p = CosMiniProgram.fromLauncherPayload(m, siteOrigin);
    return CosMarketProgram(
      program: p,
      inLauncher: _truthy(m['in_launcher']),
      userPinned: _truthy(m['user_pinned']),
    );
  }
}
