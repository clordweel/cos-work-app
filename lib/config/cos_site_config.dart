/// 编译期默认站点（可被用户设置与 [CosSiteStore] 覆盖）。
abstract final class CosSiteConfig {
  static const String defaultOriginString = String.fromEnvironment(
    'COS_SITE_ORIGIN',
    defaultValue: 'https://cos.junhai.work',
  );

  static Uri get defaultOrigin {
    return parseOrigin(defaultOriginString);
  }

  static Uri parseOrigin(String raw) {
    var s = raw.trim();
    if (s.isEmpty) {
      throw FormatException('站点地址不能为空');
    }
    if (!s.contains('://')) {
      s = 'https://$s';
    }
    final u = Uri.parse(s);
    if (!u.hasScheme || u.host.isEmpty) {
      throw FormatException('无效的站点地址: $raw');
    }
    if (u.scheme != 'https' && u.scheme != 'http') {
      throw FormatException('仅支持 http / https');
    }
    return Uri(
      scheme: u.scheme,
      host: u.host,
      port: u.hasPort ? u.port : null,
    );
  }
}
