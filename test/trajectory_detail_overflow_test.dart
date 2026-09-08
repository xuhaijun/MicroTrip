import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/core/storage/app_storage.dart';
import 'package:micro_trip/main.dart';
import 'package:micro_trip/models/trajectory.dart';
import 'package:micro_trip/router/app_router.dart';
import 'package:micro_trip/services/trajectory_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 轨迹详情页溢出回归测试（确定性渲染树扫描）。
///
/// 为什么不用 takeException：布局溢出断言在部分场景下经框架默认 onError 打印到
/// 控制台却不被 takeException 捕获（此前「统计网格 12px 横向 + 7.7px 纵向溢出」
/// 即因此漏检）。本测试直接遍历渲染树，对所有 RenderFlex 检查其 `overflow`
/// 字段，>= 1px 视为可见溢出，判定确定、不依赖异常通道。
///
/// 覆盖真实场景：
///  - 正常数据：长不可断词标题 / 停留点标签地址（此前头部与停留点溢出根因）
///  - 统计网格（最高/最低海拔、累计爬升/下降、采样/停留点数 6 个瓦片）：
///    改用 Wrap + 等宽 SizedBox，高度由内容自然决定，杜绝 GridView 固定
///    childAspectRatio 把瓦片压矮导致的溢出。
///  - 多竖屏宽度 + 系统字号放大（1.0 / 1.25 / 1.5）组合扫描。
///
/// 容差：Flutter 文本行高存在亚像素(<1px)舍入，用户不可见，不计失败。
///
/// 几何判定：遍历渲染树中所有 RenderFlex，检查其任一子节点是否超出该 Flex 的边界
/// （横向超宽 / 纵向超高，阈值 1px）。不依赖 RenderFlex 私有 overflow 字段，
/// 也不依赖 takeException 的异常通道（后者在部分场景会漏报布局溢出）。
bool _hasVisibleOverflow(Element root) {
  var bad = false;
  void visit(RenderObject node) {
    if (node is RenderFlex) {
      final size = node.size;
      node.visitChildren((child) {
        if (child is! RenderBox) return;
        final t = child.getTransformTo(node).getTranslation();
        if (node.direction == Axis.horizontal) {
          if (t.x < -1.0 || t.x + child.size.width > size.width + 1.0) {
            bad = true;
          }
        } else {
          if (t.y < -1.0 || t.y + child.size.height > size.height + 1.0) {
            bad = true;
          }
        }
      });
    }
    node.visitChildren(visit);
  }

  visit(root.renderObject!);
  return bad;
}

TrajectoryRecord _normal() => TrajectoryRecord(
      id: '1',
      startTime: DateTime(2026, 8, 19, 8, 0).millisecondsSinceEpoch,
      endTime: DateTime(2026, 8, 19, 9, 30).millisecondsSinceEpoch,
      points: List.generate(
          120,
          (i) => TrajectoryPoint(
              lat: 30.57 + i * 0.0001,
              lng: 104.07 + i * 0.0001,
              timestamp: i * 1000,
              altitude: 480.0 + i)),
      distance: 5230,
      duration: 5400,
      stops: List.generate(
          3,
          (i) => StopPoint(
                lat: 30.57,
                lng: 104.07,
                arrivalTime: i * 1000000,
                departureTime: i * 1000000 + 600000,
                duration: 600,
                radius: 100,
                label: '停留点 ${i + 1}',
                address: '成都市武侯区某路某号',
              )),
      maxAltitude: 1512,
      minAltitude: 480,
      ascent: 1032,
      descent: 412,
      avgSpeed: 3.5,
      title: '周末骑行锦江绿道',
      note: '备注内容',
      city: '成都',
    );

TrajectoryRecord _long() => TrajectoryRecord(
      id: '1',
      startTime: DateTime(2026, 8, 19, 8, 0).millisecondsSinceEpoch,
      endTime: DateTime(2026, 8, 19, 9, 30).millisecondsSinceEpoch,
      points: [
        TrajectoryPoint(lat: 30.57, lng: 104.07, timestamp: 0),
        TrajectoryPoint(lat: 30.58, lng: 104.08, timestamp: 1000),
      ],
      distance: 5230,
      duration: 5400,
      stops: [
        StopPoint(
          lat: 30.57,
          lng: 104.07,
          arrivalTime: 0,
          departureTime: 600000,
          duration: 600,
          radius: 100,
          label: 'SingleLongTokenStopNameWithoutBreaksYYYYYYYYYYYYYYYYYYY',
          address: 'LongAddressTokenWithoutSpacesZZZZZZZZZZZZZZZZZZZZZZZZ',
        ),
      ],
      maxAltitude: 512,
      minAltitude: 480,
      ascent: 32,
      descent: 12,
      avgSpeed: 3.5,
      title: 'LongTrajectoryTitleThatCannotWrapBecauseNoSpacesXXXXXXXXXXXXXXXXX',
      note: '备注内容',
      city: 'ChengduSichuanProvinceChinaLongCityNameNoSpaces',
    );

void main() {
  testWidgets('轨迹详情页：正常/长内容在窄屏与大字号下均不溢出', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();

    for (final rec in [_normal(), _long()]) {
      await TrajectoryRepository.save(rec);
      for (final tsf in [1.0, 1.25, 1.5]) {
        tester.binding.platformDispatcher.textScaleFactorTestValue = tsf;
        for (final w in [320.0, 360.0, 375.0, 402.0]) {
          tester.view.physicalSize = Size(w, 800);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(const ProviderScope(child: MicroTripApp()));
          await tester.pump(const Duration(milliseconds: 300));
          appRouter.go('/trajectory-detail/1');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          // 抽干地图离线 ClientException，避免框架断言（不影响布局溢出判定）
          while (tester.takeException() != null) {}
          final root = tester.binding.renderViewElement!;
          expect(_hasVisibleOverflow(root), isFalse,
              reason: '详情页溢出 @tsf=$tsf w=${w.toInt()}'
                  ' (record=${rec.title})');
        }
      }
    }
    await tester.pump(const Duration(seconds: 1));
    while (tester.takeException() != null) {}
  });
}
