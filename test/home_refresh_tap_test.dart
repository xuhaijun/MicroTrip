import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/pages/shared/widgets/common_widgets.dart';

void main() {
  testWidgets('首页头部刷新 IconButton 点击应触发 onPressed', (tester) async {
    int taps = 0;
    // 复刻 home_page 的 actions：一个刷新 IconButton
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradientHeader(
            title: '成都',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => taps++,
              ),
            ],
            child: const Text('header child'),
          ),
        ),
      ),
    );

    final btn = find.byType(IconButton);
    expect(btn, findsOneWidget, reason: '应存在刷新按钮');

    // onPressed 必须是可点状态（非 null）
    final widget = tester.widget<IconButton>(btn);
    expect(widget.onPressed, isNotNull, reason: 'onPressed 不应为 null');

    await tester.tap(btn);
    await tester.pump();

    expect(taps, 1, reason: '点击刷新按钮应触发 onPressed 一次');
  });
}
