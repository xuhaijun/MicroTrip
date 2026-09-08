import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/pages/shared/widgets/common_widgets.dart';

/// 复刻 weather_detail_page 中 _dayCard 的内容结构（SizedBox(88) -> AppCard -> Align(center) -> Column），
/// 用于回归保护：确保 10 天预报横向卡片的内容在 88 宽卡片内水平居中，而非落在左侧。
///
/// 根因：AppCard 重构后内层 Container 无 alignment，子内容在卡片内左对齐（Container 默认 start），
/// 导致 88 宽卡片里约 30px 宽的内容整体偏左。修复用 Align(alignment: Alignment.center) 把整列居中。
Widget _buildCard() {
  return SizedBox(
    width: 88,
    child: AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Align(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('今天', textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text('☀️', textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text('31°', textAlign: TextAlign.center),
            Text('22°', textAlign: TextAlign.center),
            SizedBox(height: 6),
            Text('晴', maxLines: 1, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('10天预报卡片内容在卡片内水平居中', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: _buildCard()))),
    );

    // 卡片（AppCard）的渲染边界
    final cardBox = tester.renderObject<RenderBox>(find.byType(AppCard));
    final cardCenterX = cardBox.localToGlobal(Offset.zero).dx + cardBox.size.width / 2;

    // 抽样卡片内多个文本，断言它们都基本位于卡片水平中心
    for (final t in ['今天', '☀️', '31°', '22°', '晴']) {
      final textBox = tester.renderObject<RenderBox>(find.text(t));
      final textCenterX = textBox.localToGlobal(Offset.zero).dx + textBox.size.width / 2;
      // 容差 2px：允许像素舍入误差，但绝不能是"偏左约 29px"那种明显偏移
      expect((textCenterX - cardCenterX).abs(), lessThan(2.0),
          reason: '文本「$t」应水平居中于卡片（偏差 ${(textCenterX - cardCenterX).abs().toStringAsFixed(1)}px）');
    }
  });
}
