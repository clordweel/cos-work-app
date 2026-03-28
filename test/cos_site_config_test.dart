import 'package:cos_work_app/config/cos_site_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CosSiteConfig.parseOrigin', () {
    test('补全 https 与去路径', () {
      final u = CosSiteConfig.parseOrigin('cos.example.com');
      expect(u.scheme, 'https');
      expect(u.host, 'cos.example.com');
      expect(u.hasPort, false);
    });

    test('保留显式端口', () {
      final u = CosSiteConfig.parseOrigin('http://dev.local:8080');
      expect(u.scheme, 'http');
      expect(u.host, 'dev.local');
      expect(u.port, 8080);
    });

    test('空串抛错', () {
      expect(() => CosSiteConfig.parseOrigin(''), throwsFormatException);
      expect(() => CosSiteConfig.parseOrigin('   '), throwsFormatException);
    });
  });
}
