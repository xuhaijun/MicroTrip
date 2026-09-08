import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回归：一键体验必须幂等——首次注册成功，再次点击应自动登录复用同一演示账号，
/// 不应误报「该手机号已注册，请直接登录」（修复 Phase 7 体验按钮误报问题）。
void main() {
  setUp(() async {
    // 本地模式：不配置后端地址
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    await AuthService.setServerUrl('');
  });

  test('首次体验注册，再次体验自动登录（不报已注册）', () async {
    // 第一次：演示账号不存在 → 注册
    final first = await AuthService.experience();
    expect(first.phone, '13800000000', reason: '应建立固定演示账号');
    expect(AuthService.isLoggedIn, isTrue, reason: '首次体验后应已登录');

    // 第二次：演示账号已存在 → 应自动登录，而非抛「已注册」
    final second = await AuthService.experience();
    expect(second.phone, '13800000000', reason: '应复用同一演示身份');
    expect(AuthService.isLoggedIn, isTrue);
  });

  test('体验账号与手动注册同名应被复用而非冲突', () async {
    // 先手动注册同一手机号（模拟用户曾用该号注册过）
    await AuthService.register(
      phone: '13800000000',
      password: '123456',
      nickname: '小明',
    );
    // 体验按钮点击 → 应登录「小明」而非报错
    final user = await AuthService.experience();
    expect(user.nickname, '小明', reason: '应复用已有账号昵称');
  });
}
