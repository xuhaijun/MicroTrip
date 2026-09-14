import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/main.dart';
import 'package:micro_trip/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 天气详情页「未来 24 小时」轨道高度契约（2026-09-14）。
///
/// 背景：把 24 小时轨道从 120 收到 90 后，逐小时条目的温度行「21°」按 fontSize 16
/// 排版需要约 49px，而槽宽只有 48px → 折成两行（实测 46 高），整列变成
/// 14.4+8+22+8+46 = 101 → 溢出 11px。
///
/// 为什么别的用例抓不到：首页天气卡的一系列 tap 用例、overflow_scan 都用
/// `while (tester.takeException() != null) {}` 抽干异常（这是为了吃掉 flutter_map 的
/// ClientException），溢出被一起吞掉 → **真机 debug 包有黄黑条纹、测试却全绿**。
/// 所以这类"固定高度轨道"必须有独立用例显式断言不溢出。
///
/// 修法：Text 加 maxLines/softWrap 禁折行 + 显式 height（中文默认行高约 1.42，
/// 不写死会估算失真）+ FittedBox(scaleDown) 兜底极端字体缩放。
void main() {
  /// 抽干 pending 异常并逐条返回文本（便于断言里输出溢出原文）
  List<String> drain(WidgetTester tester) {
    final out = <String>[];
    Object? e;
    while ((e = tester.takeException()) != null) {
      out.add(e.toString());
    }
    return out;
  }

  testWidgets('未来24小时轨道不溢出，且温度行不折行', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    // 强制 mock 数据，避免一直 loading、拿不到逐小时条目
    await AppStorage.setBool(AppStorage.kUseMockData, true);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844); // iPhone 14/15

    await tester.pumpWidget(const ProviderScope(child: MicroTripApp()));
    await tester.pump(const Duration(milliseconds: 300));
    final errors = <String>[...drain(tester)];

    appRouter.go('/weather-detail');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    errors.addAll(drain(tester));
    // 让 FadeSlideIn 的一次性定时器跑完，顺带抓最后一批布局异常
    await tester.pump(const Duration(seconds: 1));
    errors.addAll(drain(tester));

    final overflows =
        errors.where((e) => e.contains('overflowed')).toList(growable: false);
    expect(overflows, isEmpty,
        reason: '天气详情页出现布局溢出（真机会显示黄黑条纹）：\n${overflows.join('\n')}');

    // ---- 逐小时条目：width == 48 的 SizedBox，其内是 FittedBox → Column ----
    final items = find.byWidgetPredicate((w) => w is SizedBox && w.width == 48);
    expect(items, findsWidgets, reason: '天气详情页应有逐小时条目');

    // ---- 每个条目的温度行必须是单行 ----
    var checked = 0;
    for (final element in items.evaluate()) {
      final paragraphs = find
          .descendant(of: find.byElementPredicate((e) => e == element),
              matching: find.byType(Text))
          .evaluate()
          .map((e) => e.renderObject)
          .whereType<RenderParagraph>()
          .where((rp) => rp.text.toPlainText().endsWith('°'));
      for (final rp in paragraphs) {
        final text = rp.text.toPlainText();
        // 用选区盒子数出视觉行数：折行会让整列高度失控（本次溢出的根因）
        final lines = rp
            .getBoxesForSelection(TextSelection(
                baseOffset: 0, extentOffset: rp.text.toPlainText().length))
            .map((b) => b.top.round())
            .toSet()
            .length;
        expect(lines, 1, reason: '温度文本「$text」折成了 $lines 行（槽宽 48 太窄）');
        checked++;
      }
    }
    expect(checked, greaterThan(0), reason: '没有检查到任何温度文本，用例可能失效了');
  });
}
