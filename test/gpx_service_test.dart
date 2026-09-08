import 'package:flutter_test/flutter_test.dart';

import 'package:micro_trip/models/trajectory.dart';
import 'package:micro_trip/services/gpx_service.dart';

/// GPX 导出 / 合并服务单元测试（纯 Dart，无需设备）
///
/// 覆盖：
///  1. 单条导出 → 生成合法 GPX（含 gpx/trk/trkseg/trkpt）
///  2. 导出回读 → parseGpx 还原点数与坐标（往返一致）
///  3. 多轨迹合并 → 点数合并、距离/爬升重算、时长取跨度
///  4. 合并导出 → 单个 GPX 含多条 `<trkseg>`
void main() {
  // 构造一条带海拔/时间的小轨迹
  TrajectoryRecord makeRecord(String id, int startOffset) {
    final base = 1700000000000 + startOffset;
    final points = <TrajectoryPoint>[
      TrajectoryPoint(
          lat: 30.570, lng: 104.070, timestamp: base, altitude: 500, speed: 2.0),
      TrajectoryPoint(
          lat: 30.571, lng: 104.071, timestamp: base + 10000,
          altitude: 505, speed: 2.5),
      TrajectoryPoint(
          lat: 30.572, lng: 104.072, timestamp: base + 20000,
          altitude: 510, speed: 3.0, heading: 90),
    ];
    return TrajectoryRecord(
      id: id,
      startTime: base,
      endTime: base + 20000,
      points: points,
      distance: 300,
      duration: 20,
      stops: const [],
      maxAltitude: 510,
      minAltitude: 500,
      ascent: 10,
      descent: 0,
      avgSpeed: 54,
      title: '测试轨迹$id',
      city: '成都',
    );
  }

  group('GpxService 导出', () {
    test('exportTrackToGpx 生成合法 GPX 结构', () {
      final rec = makeRecord('a1', 0);
      final gpx = GpxService.exportTrackToGpx(rec);

      expect(gpx, contains('<gpx'));
      expect(gpx, contains('version="1.1"'));
      expect(gpx, contains('<trk>'));
      expect(gpx, contains('<trkseg>'));
      expect(gpx, contains('<trkpt lat="30.5700000"'));
      expect(gpx, contains('lon="104.0700000"'));
      expect(gpx, contains('<ele>500.0</ele>'));
      expect(gpx, contains('<time>'));
      expect(gpx, contains('<speed>2.00</speed>'));
      // 自定义扩展命名空间
      expect(gpx, contains('xmlns:mt='));
    });

    test('parseGpx 可回读导出内容（往返一致）', () {
      final rec = makeRecord('a2', 1000);
      final gpx = GpxService.exportTrackToGpx(rec);
      final parsed = GpxService.parseGpx(gpx);

      expect(parsed.length, 1);
      final back = parsed.first;
      expect(back.points.length, rec.points.length);
      expect(back.points.first.lat, 30.570);
      expect(back.points.first.lng, 104.070);
      expect(back.points.first.altitude, 500);
      expect(back.title, '测试轨迹a2');
      expect(back.city, '成都');
    });
  });

  group('GpxService 合并', () {
    test('mergeRecords 合并点数并保留统计', () {
      final r1 = makeRecord('m1', 0);
      final r2 = makeRecord('m2', 60000); // 时间错开，避免重叠
      final merged = GpxService.mergeRecords([r1, r2]);

      // 点数 = 3 + 3
      expect(merged.points.length, 6);
      // 时长取跨度（约 80 秒）
      expect(merged.duration, greaterThanOrEqualTo(60));
      // 标题自动命名
      expect(merged.title, contains('合并轨迹'));
      // 海拔极值保留
      expect(merged.maxAltitude, 510);
      expect(merged.minAltitude, 500);
    });

    test('exportMergedGpx 含多条 trkseg', () {
      final r1 = makeRecord('x1', 0);
      final r2 = makeRecord('x2', 60000);
      final gpx = GpxService.exportMergedGpx([r1, r2]);

      // 每条轨迹一个 trkseg
      expect(gpx, contains('<trkseg>'));
      expect('trkseg'.allMatches(gpx).length, greaterThanOrEqualTo(2));
      expect(gpx, contains('合并轨迹'));
    });

    test('单条合并直接返回原记录', () {
      final r1 = makeRecord('s1', 0);
      final merged = GpxService.mergeRecords([r1]);
      expect(merged.id, r1.id);
    });

    test('空列表合并抛异常', () {
      expect(() => GpxService.mergeRecords([]), throwsArgumentError);
    });
  });
}
