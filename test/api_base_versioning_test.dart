import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 接口版本化（v1）回归测试（2026-09-10）。
///
/// 约定：客户端所有业务接口统一走规范路径 `{serverUrl}/api/v1/...`
/// （服务端同时映射历史裸路径，但客户端只认规范路径）。
/// 本测试钉住 [AuthService.apiBase] 的拼接规则，防止：
///  - 有人改回裸路径（回归到不规范的 `/auth/login`）；
///  - 用户在设置页把含 `/api/v1` 的地址整个填进来 → 拼出 `/api/v1/api/v1` 全部 404。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
  });

  /// 经设置页入口写入 serverUrl（与真实用户路径一致）
  Future<void> setUrl(String url) async {
    await AuthService.setServerUrl(url);
  }

  test('未配置后端时 apiBase 为空（本地演示模式）', () {
    expect(AuthService.apiBase, isEmpty);
  });

  test('常规地址追加 /api/v1', () async {
    await setUrl('http://10.0.2.2:3000');
    expect(AuthService.apiBase, 'http://10.0.2.2:3000/api/v1');
  });

  test('尾部多余的斜杠被归一化，不会拼出 //api/v1', () async {
    await setUrl('http://10.0.2.2:3000///');
    expect(AuthService.apiBase, 'http://10.0.2.2:3000/api/v1');
  });

  test('用户直接填了含 /api/v1 的地址 → 不重复追加', () async {
    await setUrl('https://api.example.com/api/v1');
    expect(AuthService.apiBase, 'https://api.example.com/api/v1');
  });

  test('含 /api/v1 且带尾部斜杠 → 归一化后不重复追加', () async {
    await setUrl('https://api.example.com/api/v1/');
    expect(AuthService.apiBase, 'https://api.example.com/api/v1');
  });

  test('大小写不敏感地识别已带版本段（/API/V1）', () async {
    await setUrl('https://api.example.com/API/V1');
    expect(AuthService.apiBase, 'https://api.example.com/API/V1');
  });

  test('serverUrl 本身不含版本段（保持用户原始输入，仅去尾斜杠）', () async {
    await setUrl('http://192.168.1.8:3000');
    expect(AuthService.serverUrl, 'http://192.168.1.8:3000');
  });
}
