import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/config/app_config.dart';
import 'package:micro_trip/pages/profile/privacy_policy_page.dart';
import 'package:micro_trip/pages/profile/user_agreement_page.dart';

/// 上架合规回归：联系邮箱必须是真实邮箱，且整个工程里只能有一处定义。
///
/// 背景：隐私政策页 / 用户协议页此前写死了占位邮箱 `privacy@microtrip.example`，
/// 各渠道审核会以「联系不上运营方」驳回。现统一收敛到 [AppConfig.contactEmail]，
/// 本测试同时守住「正文确实引用了该常量」与「常量本身是真实邮箱」两点。
void main() {
  /// 真实邮箱：非 example.com 之类不可投递的占位域
  const String realEmail = 'xuhaijun5382@163.com';

  test('AppConfig.contactEmail 为真实可投递邮箱', () {
    expect(AppConfig.contactEmail, realEmail);
    expect(AppConfig.contactEmail, contains('@'));
    expect(AppConfig.contactEmail, isNot(contains('example.com')));
    expect(AppConfig.contactEmail, isNot(contains('microtrip.example')));
  });

  testWidgets('隐私政策页展示真实联系邮箱，不含占位邮箱', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyPage()));
    await tester.pumpAndSettle();

    // 正文里两处引用（「九、联系我们」+ 页脚说明）都应渲染出真实邮箱
    expect(
      find.textContaining(realEmail),
      findsWidgets,
      reason: '隐私政策正文应包含真实联系邮箱',
    );
    expect(
      find.textContaining('microtrip.example'),
      findsNothing,
      reason: '不应残留任何占位邮箱',
    );
  });

  testWidgets('用户协议页展示真实联系邮箱，不含占位邮箱', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UserAgreementPage()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(realEmail),
      findsWidgets,
      reason: '用户协议正文应包含真实联系邮箱',
    );
    expect(find.textContaining('microtrip.example'), findsNothing);
  });
}
