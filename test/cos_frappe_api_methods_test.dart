import 'package:cos_work_app/config/cos_frappe_api_methods.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pathFor 生成标准 method 路径', () {
    expect(
      CosFrappeApiMethods.pathFor(CosFrappeApiMethods.login),
      '/api/method/login',
    );
    expect(
      CosFrappeApiMethods.pathFor(CosFrappeApiMethods.getLauncherPrograms),
      '/api/method/cos.work_app_launcher_api.get_launcher_programs',
    );
  });

  test('uri 保留站点 scheme/host/port', () {
    final o = Uri.parse('https://cos.example.com');
    final u = CosFrappeApiMethods.uri(o, CosFrappeApiMethods.getLoggedUser);
    expect(u.toString(), 'https://cos.example.com/api/method/frappe.auth.get_logged_user');
  });
}
