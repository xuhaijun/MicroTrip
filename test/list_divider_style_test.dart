import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/pages/profile/about_page.dart';
import 'package:micro_trip/pages/profile/permission_manage_page.dart';
import 'package:micro_trip/pages/profile/profile_page.dart';
import 'package:micro_trip/pages/profile/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全 App「卡片内列表分隔线」观感契约。
///
/// 背景：用户反馈「列表项之间的间隔线条不好看」。真因是分隔线取 `Divider()` 默认值
/// ——左右两端都顶到卡片内缘，既没对齐文字、也不留白（「我的」页 / 关于页 / 权限页 /
/// 设置页四处同款问题）。
///
/// 统一后的规则：**左端对齐行内文字左边界、右端内缩 12、两端都不顶到卡片内缘**。
///
/// 为什么值得写用例：`indent` 的取值（40 / 48 / 56 / 70）全都是从「该页行内文字
/// 实测左边界」推出来的常量，一旦 Flutter 调整 ListTile 内部布局
/// （M3 的 `minLeadingWidth` 已从 M2 的 40 改成 24）、或有人给某行加了
/// `contentPadding`，常量就与文字脱钩、线又会错位 —— 而 `flutter analyze`
/// 对此**一无所知**。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // AppStorage 是 late 单例，需在读取前初始化
    await AppStorage.init();
  });

  /// 取「实际画出来的那条线」的 Finder。
  ///
  /// 坑：`getRect(Divider)` 与 `getRect(内层 Container)` **都返回全宽**，
  /// `indent/endIndent` 一点都不体现（走查时差点据此误判「indent 没生效」）。
  /// 实测 Flutter 的渲染树是
  /// `Divider > SizedBox > Center > Container > Padding > ConstrainedBox > DecoratedBox`，
  /// 外层全宽，**只有 DecoratedBox 被 margin 内缩** —— 那才是可见的线。
  /// 验证：`SizedBox(width: 300)` 内 indent 40 / endIndent 12 的线落在 [85, 333]，
  /// 正好是 45+40 .. 345−12。
  Finder lineOf(Finder divider, int index) {
    final inner =
        find.descendant(of: divider, matching: find.byType(DecoratedBox));
    expect(inner, findsOneWidget,
        reason: '第 $index 条分隔线内部结构变了（Divider 实现调整），无法取证画线几何');
    return inner;
  }

  /// 收集页面内所有「列表分隔线」（`height == 1`）及其**画线**矩形。
  /// `height: 24` 的是配置卡内的字段分组线，另一种用途，不在本契约范围。
  List<(Divider, Rect)> listLines(WidgetTester tester) {
    final out = <(Divider, Rect)>[];
    final dividers = find.byType(Divider);
    for (int i = 0; i < dividers.evaluate().length; i++) {
      final d = tester.widget<Divider>(dividers.at(i));
      if (d.height != 1) continue;
      out.add((d, tester.getRect(lineOf(dividers.at(i), i))));
    }
    return out;
  }

  Future<void> pumpPage(WidgetTester tester, Widget app,
      {bool settle = true}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // 有持续动画的页面（权限管理页）pumpAndSettle 会超时
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('设置页：线左端对齐标题文字、右端内缩 12', (tester) async {
    await pumpPage(tester,
        const ProviderScope(child: MaterialApp(home: SettingsPage())));

    // 以「数据与位置」卡的开关行为锚点：该行恒定渲染，
    // 且 contentPadding 为 zero —— 与所有被分隔线切分的行同款。
    final anchor = find.ancestor(
        of: find.text('使用模拟数据'), matching: find.byType(ListTile));
    expect(anchor, findsOneWidget, reason: '锚点行缺失，用例前提不成立');

    final rowLeft = tester.getRect(anchor).left;
    final rowRight = tester.getRect(anchor).right;
    final titleLeft = tester
        .getTopLeft(find.descendant(of: anchor, matching: find.byType(Text)).first)
        .dx;

    // 标题起点 = max(minLeadingWidth 24(M3), 图标 20) + horizontalTitleGap 16 = 40
    const double kIndent = 40;
    expect(titleLeft - rowLeft, closeTo(kIndent, 0.5),
        reason: '行标题文字的实测位移变了（现为 ${titleLeft - rowLeft}），'
            '需同步 settings_page.dart 里 _kListDivider 的 indent');

    final lines = listLines(tester);
    expect(lines, isNotEmpty, reason: '卡片内列表分隔线一条都没渲染，契约失效');
    for (final (d, r) in lines) {
      expect(d.indent, kIndent);
      expect(d.endIndent, 12);
      expect(r.left, closeTo(titleLeft, 0.5), reason: '线左端未对齐标题文字');
      expect(r.right, closeTo(rowRight - 12, 0.5), reason: '线右端未内缩 12');
      // 两条「不是全宽线」的兜底断言：防止被改回 Divider() 默认值
      expect(r.left, greaterThan(rowLeft), reason: '线左端未内缩，退回全宽线了');
      expect(r.right, lessThan(rowRight), reason: '线右端顶到卡片内缘了');
    }
  });

  testWidgets('我的页：线左端对齐行标题文字、右端内缩 12', (tester) async {
    await pumpPage(tester,
        const ProviderScope(child: MaterialApp(home: ProfilePage())));

    // _Tile 行内文字起点 = 卡片内边距 + 行内边距 + 图标 22 + 间距 14 = 48
    final titleLeft = tester.getTopLeft(find.text('我的收藏')).dx;

    final lines = listLines(tester);
    expect(lines.length, greaterThanOrEqualTo(5),
        reason: '「我的」页有 6 条列表分隔线，少于此说明被删或不再渲染');
    for (final (d, r) in lines) {
      expect(d.endIndent, 12, reason: '右端内缩统一为 12');
      expect(r.left, closeTo(titleLeft, 0.5), reason: '线左端未对齐行标题文字');
    }
  });

  testWidgets('关于页：信息行线对齐标签文字、入口行线对齐标题文字', (tester) async {
    await pumpPage(tester, const MaterialApp(home: AboutPage()));

    final infoTextLeft = tester.getTopLeft(find.text('项目')).dx;
    final tileTitleLeft = tester.getTopLeft(find.text('用户协议')).dx;
    expect(infoTextLeft, isNot(tileTitleLeft),
        reason: '两种行的文字起点应当不同（信息行无前置图标），用例前提不成立');

    final lines = listLines(tester);
    expect(lines.length, greaterThanOrEqualTo(4));
    for (final (d, r) in lines) {
      expect(d.endIndent, 12, reason: '右端内缩统一为 12');
      final bool aligned = (r.left - infoTextLeft).abs() < 0.5 ||
          (r.left - tileTitleLeft).abs() < 0.5;
      expect(aligned, isTrue,
          reason: '线左端 ${r.left} 未落在任一行文字左边界上'
              '（信息行 $infoTextLeft / 入口行 $tileTitleLeft）');
    }
  });

  testWidgets('权限管理页：线左端对齐权限名、右端内缩 12', (tester) async {
    await pumpPage(tester, const MaterialApp(home: PermissionManagePage()),
        settle: false);

    final titleLeft = tester.getTopLeft(find.text('定位')).dx;

    final lines = listLines(tester);
    expect(lines, isNotEmpty);
    for (final (d, r) in lines) {
      expect(d.endIndent, 12, reason: '右端内缩统一为 12');
      expect(r.left, closeTo(titleLeft, 0.5), reason: '线左端未对齐权限名文字');
    }
  });
}
