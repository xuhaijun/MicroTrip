import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/models/cloud_stats.dart';

/// ============================================================
/// 云端足迹统计模型（CloudStats）单元测试
///
/// 覆盖两类容易出错的地方：
///  1. **解析容错**：服务端字段可空（无轨迹时 maxDistance/firstStart 为 null），
///     且未来可能新增/调整字段 —— 任何缺失都不能让「我的」页整块报错；
///  2. **单位换算**：服务端契约是「米 / 秒 / 毫秒」，展示要变成 km / 小时 / 日期。
///     这是最容易写错又最不容易被发现的地方（数字看着都对，单位差 1000 倍）。
/// ============================================================
void main() {
  group('CloudStats.fromMap 解析', () {
    test('完整字段正常解析', () {
      final s = CloudStats.fromMap({
        'count': 12,
        'totalDistance': 45678.9,
        'totalDuration': 9000,
        'totalAscent': 1234.6,
        'totalDescent': 1100.2,
        'maxDistance': 12345.0,
        'maxAvgSpeed': 8.5,
        'firstStart': 1742000000000,
        'lastStart': 1757000000000,
        'lastSyncedAt': 1757500000000,
        'totalPoints': 45678,
      });

      expect(s.count, 12);
      expect(s.totalDistance, 45678.9);
      expect(s.totalDuration, 9000);
      expect(s.totalAscent, 1234.6);
      expect(s.maxDistance, 12345.0);
      expect(s.maxAvgSpeed, 8.5);
      expect(s.firstStart, 1742000000000);
      expect(s.lastStart, 1757000000000);
      expect(s.lastSyncedAt, 1757500000000);
      expect(s.totalPoints, 45678);
      expect(s.isEmpty, isFalse);
    });

    test('无轨迹：count=0 且可空聚合为 null，不应抛异常', () {
      // 服务端 TrajectoryStatsDto 带 @JsonInclude(NON_NULL)，
      // 无数据时 maxDistance / firstStart / lastStart / lastSyncedAt 直接不出现在 JSON 里
      final s = CloudStats.fromMap({
        'count': 0,
        'totalDistance': 0.0,
        'totalDuration': 0,
        'totalAscent': 0.0,
        'totalDescent': 0.0,
        'totalPoints': 0,
      });

      expect(s.count, 0);
      expect(s.maxDistance, isNull);
      expect(s.maxAvgSpeed, isNull);
      expect(s.firstStart, isNull);
      expect(s.lastStart, isNull);
      expect(s.lastSyncedAt, isNull);
      expect(s.isEmpty, isTrue);
    });

    test('字段全缺 / 类型异常：按 0 处理，不抛异常', () {
      final empty = CloudStats.fromMap(<String, dynamic>{});
      expect(empty.count, 0);
      expect(empty.totalDistance, 0.0);
      expect(empty.totalDuration, 0);
      expect(empty.totalPoints, 0);
      expect(empty.isEmpty, isTrue);

      // 故意给字符串/布尔等非数值类型：不能崩，退化为 0
      final weird = CloudStats.fromMap({
        'count': 'NaN',
        'totalDistance': true,
        'totalDuration': null,
        'totalPoints': <String>[],
      });
      expect(weird.count, 0);
      expect(weird.totalDistance, 0.0);
      expect(weird.totalDuration, 0);
      expect(weird.totalPoints, 0);
    });

    test('int 与 double 可互换（JSON 数值类型不固定）', () {
      final s = CloudStats.fromMap({
        'count': 3,
        'totalDistance': 1000, // int 形式的米
        'totalDuration': 3600.0, // double 形式的秒
        'totalAscent': 0,
        'totalDescent': 0,
        'totalPoints': 100,
      });
      expect(s.totalDistance, 1000.0);
      expect(s.totalDuration, 3600);
    });

    test('CloudStats.empty 是安全默认值', () {
      expect(CloudStats.empty.count, 0);
      expect(CloudStats.empty.isEmpty, isTrue);
      expect(CloudStats.empty.totalPoints, 0);
    });
  });

  group('距离单位换算（米 → km）', () {
    test('≥1km 保留 1 位小数', () {
      expect(_m(totalDistance: 12345).totalDistanceKmText, '12.3');
      expect(_m(totalDistance: 1000).totalDistanceKmText, '1.0');
      expect(_m(totalDistance: 99990).totalDistanceKmText, '100.0');
    });

    test('<1km 保留 2 位小数（否则 850m 会显示成 0.0，信息全丢）', () {
      expect(_m(totalDistance: 850).totalDistanceKmText, '0.85');
      expect(_m(totalDistance: 50).totalDistanceKmText, '0.05');
    });

    test('0 米', () {
      expect(_m(totalDistance: 0).totalDistanceKmText, '0.00');
    });

    test('maxDistance 为 null 时给占位符而不是崩溃', () {
      expect(_m().maxDistanceText, '—');
      expect(_m(maxDistance: 0).maxDistanceText, '—');
      expect(_m(maxDistance: 5432).maxDistanceText, '5.4 km');
    });
  });

  group('时长格式化（秒 → 可读文本）', () {
    test('不足 1 小时只显示分钟', () {
      expect(_m(totalDuration: 2700).totalDurationText, '45 分钟'); // 45 分钟
      expect(_m(totalDuration: 59).totalDurationText, '0 分钟'); // 不足 1 分钟
      expect(_m(totalDuration: 0).totalDurationText, '0 分钟');
    });

    test('整小时不带「0 分」尾巴', () {
      expect(_m(totalDuration: 7200).totalDurationText, '2 小时');
    });

    test('小时 + 分钟', () {
      expect(_m(totalDuration: 9000).totalDurationText, '2 小时 30 分');
    });

    test('小时数值保留 1 位小数', () {
      expect(_m(totalDuration: 5400).totalDurationHourText, '1.5');
      expect(_m(totalDuration: 0).totalDurationHourText, '0.0');
    });
  });

  group('数值格式化', () {
    test('爬升下降取整（服务端是 Double，直接显示会出现一堆小数）', () {
      expect(_m(totalAscent: 1234.6).totalAscentText, '1235');
      expect(_m(totalAscent: 0).totalAscentText, '0');
      expect(_m(totalDescent: 999.4).totalDescentText, '999');
    });

    test('采样点数 / 轨迹数带千分位', () {
      expect(_m(totalPoints: 45678).totalPointsText, '45,678');
      expect(_m(totalPoints: 999).totalPointsText, '999');
      expect(_m(totalPoints: 1000000).totalPointsText, '1,000,000');
      expect(_m(count: 1234).countText, '1,234');
    });
  });

  group('时间展示', () {
    test('出行时间范围', () {
      // 用构造的本地时间避免时区差异影响断言
      final a = DateTime(2026, 3, 15).millisecondsSinceEpoch;
      final b = DateTime(2026, 9, 10).millisecondsSinceEpoch;
      expect(_m(firstStart: a, lastStart: b).rangeText, '2026/03/15 — 2026/09/10');
    });

    test('无数据时范围显示占位符', () {
      expect(_m().rangeText, '—');
    });

    test('从未同步', () {
      expect(_m().lastSyncedText, '从未同步');
      expect(_m(lastSyncedAt: 0).lastSyncedText, '从未同步');
    });

    test('同步时间为相对文本', () {
      final now = DateTime.now();
      expect(_m(lastSyncedAt: now.millisecondsSinceEpoch).lastSyncedText, '刚刚');
      expect(
        _m(lastSyncedAt: now.subtract(const Duration(minutes: 12))
                .millisecondsSinceEpoch)
            .lastSyncedText,
        '12 分钟前',
      );
      expect(
        _m(lastSyncedAt: now.subtract(const Duration(hours: 3))
                .millisecondsSinceEpoch)
            .lastSyncedText,
        '3 小时前',
      );
    });

    test('最近出行：今天 / 昨天 / N 天前', () {
      final now = DateTime.now();
      expect(_m(lastStart: now.millisecondsSinceEpoch).lastTripText, '今天');
      expect(
        _m(lastStart: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch)
            .lastTripText,
        '昨天',
      );
      expect(
        _m(lastStart: now.subtract(const Duration(days: 5)).millisecondsSinceEpoch)
            .lastTripText,
        '5 天前',
      );
      expect(_m().lastTripText, '暂无出行记录');
    });

    test('距上次出行天数（用于"该出门了"类提示）', () {
      final now = DateTime.now();
      expect(
        _m(lastStart: now.subtract(const Duration(days: 7)).millisecondsSinceEpoch)
            .daysSinceLastTrip,
        7,
      );
      expect(_m().daysSinceLastTrip, isNull);
    });
  });

  group('本地 vs 云端差异提示', () {
    test('一致 / 云端更多 / 云端更少', () {
      expect(_m(count: 5).diffHint(5), '与本地记录一致');
      expect(_m(count: 8).diffHint(5), contains('多 3 条'));
      expect(_m(count: 2).diffHint(5), contains('少 3 条'));
    });

    test('提示文案说明原因（避免用户误以为数据丢失）', () {
      expect(_m(count: 8).diffHint(5), contains('其他设备'));
      expect(_m(count: 2).diffHint(5), contains('未同步'));
    });
  });
}

/// 构造一个只关心少数字段的 CloudStats，未指定的字段给 0
CloudStats _m({
  int count = 0,
  double totalDistance = 0,
  int totalDuration = 0,
  double totalAscent = 0,
  double totalDescent = 0,
  double? maxDistance,
  int? firstStart,
  int? lastStart,
  int? lastSyncedAt,
  int totalPoints = 0,
}) =>
    CloudStats(
      count: count,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      totalAscent: totalAscent,
      totalDescent: totalDescent,
      maxDistance: maxDistance,
      firstStart: firstStart,
      lastStart: lastStart,
      lastSyncedAt: lastSyncedAt,
      totalPoints: totalPoints,
    );
