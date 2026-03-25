import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cos_site_config.dart';

const String _kPrefsSiteOrigin = 'cos_site_origin_override';

/// 运行时站点根地址（用户可在设置中修改，持久化到 SharedPreferences）。
class CosSiteStore extends ChangeNotifier {
  CosSiteStore._();
  static final CosSiteStore instance = CosSiteStore._();

  Uri? _origin;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// 当前站点根；未初始化前勿用。
  Uri get origin {
    final o = _origin;
    if (o == null) {
      throw StateError('CosSiteStore 尚未 init');
    }
    return o;
  }

  String get originDisplay => _origin?.toString() ?? '';

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefsSiteOrigin);
    try {
      _origin = saved != null && saved.isNotEmpty
          ? CosSiteConfig.parseOrigin(saved)
          : CosSiteConfig.defaultOrigin;
    } catch (_) {
      _origin = CosSiteConfig.defaultOrigin;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setOrigin(String raw) async {
    final parsed = CosSiteConfig.parseOrigin(raw);
    _origin = parsed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsSiteOrigin, parsed.toString());
    notifyListeners();
  }

  Future<void> clearSavedOrigin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsSiteOrigin);
    _origin = CosSiteConfig.defaultOrigin;
    notifyListeners();
  }
}
