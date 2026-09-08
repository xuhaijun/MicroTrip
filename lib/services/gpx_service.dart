import '../core/storage/app_storage.dart';
import '../models/trajectory.dart';
import '../services/trajectory_service.dart';

/// ============================================================
/// GPX 轨迹导出 / 合并服务（P1：上架四件套之一）
///
/// GPX（GPS Exchange Format）是开放的 GPS 轨迹交换标准，可被
/// Google Earth、Strava、OsmAnd、GPX Viewer 等几乎所有运动 /
/// 地图类软件读取。本项目用它解决两个上架/分享需求：
///
///  1. 【导出】把单条 / 多条本地轨迹导出为标准 .gpx 文件，通过
///     系统分享面板发给好友或导入第三方 App。
///  2. 【合并】把多条轨迹按时间顺序拼接成一条「合并轨迹」，
///     既可在 App 内长期保存，也可导出为单个 .gpx 文件。
///
/// 设计要点：
///  - 零新增依赖，纯 Dart 字符串拼接 + 正则回读；
///  - 采用 GPX 1.1 标准，`<trk>`/`<trkseg>`/`<trkpt>` 结构；
///  - 自定义字段（accuracy/heading）放在 mt: 命名空间下，
///    保证文件对第三方解析器依然合法；
///  - [parseGpx] 支持回读，为「从外部 .gpx 文件导入并合并」
///    预留能力（当前 UI 仅做本地轨迹合并）。
///
/// 对应小程序无此能力 —— 这是 Flutter 版相对小程序的上架增强。
/// ============================================================

class GpxService {
  GpxService._();

  /// 命名空间（自定义扩展字段用）
  static const String _ns = 'http://microtrip.local/gpx';

  /// 合并记录时的距离重算阈值（米）：小于此值的相邻点差视为噪声跳过
  static const double _mergeMinMove = 1.0;
  /// 合并记录时的海拔变化阈值（米）
  static const double _mergeAltThreshold = 1.0;

  // ============================================================
  // 导出：单条轨迹 → GPX 字符串
  // ============================================================

  /// 把单条轨迹导出为标准 GPX 1.1 文档（一个 `<trk>`）。
  static String exportTrackToGpx(TrajectoryRecord record) {
    final trkseg = _buildTrkseg(record.points);
    final desc =
        '距离 ${record.distanceText} · 时长 ${record.durationText} · 采样点 ${record.points.length}';
    return _wrapGpx(
      metadataName: record.displayTitle,
      metadataTime: record.startTime,
      body: '''
  <trk>
    <name>${_xml(record.displayTitle)}</name>
    <desc>${_xml(desc)}</desc>${_extensions(record)}
    $trkseg
  </trk>''',
    );
  }

  /// 把多条轨迹合并导出为单个 GPX 文档（一个 `<trk>`，每段一条 `<trkseg>`）。
  ///
  /// 每条轨迹对应一个独立 `<trkseg>`，段之间不连成一条折线，
  /// 避免不同轨迹的「接缝」被画成错误连线。
  static String exportMergedGpx(List<TrajectoryRecord> records) {
    if (records.isEmpty) return _wrapGpx(metadataName: '微旅途轨迹', body: '');
    // 按开始时间排序，保证段顺序合理
    final sorted = [...records]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final merged = mergeRecords(sorted);
    final segments = sorted
        .map((r) => _buildTrkseg(r.points, name: r.displayTitle))
        .join('\n');
    final desc =
        '由 ${records.length} 条轨迹合并 · 距离 ${merged.distanceText} · 时长 ${merged.durationText}';
    return _wrapGpx(
      metadataName: merged.displayTitle,
      metadataTime: merged.startTime,
      body: '''
  <trk>
    <name>${_xml(merged.displayTitle)}</name>
    <desc>${_xml(desc)}</desc>${_extensions(merged)}
$segments
  </trk>''',
    );
  }

  // ============================================================
  // 合并：多条轨迹 → 单条 TrajectoryRecord
  // ============================================================

  /// 把多条本地轨迹合并为一条 [TrajectoryRecord]。
  ///
  /// 处理：
  ///  - 所有采样点按时间戳升序拼接（去重同一毫秒点）；
  ///  - 距离 / 爬升 / 下降 / 最高最低海拔重新统计（保证数值自洽）；
  ///  - 停留点全部保留并按到达时间排序；
  ///  - 时长取「首条起点 → 末条终点」的时间跨度。
  static TrajectoryRecord mergeRecords(List<TrajectoryRecord> records) {
    if (records.isEmpty) {
      throw ArgumentError('至少需要一条轨迹才能合并');
    }
    if (records.length == 1) return records.first;

    final allPoints = <TrajectoryPoint>[];
    for (final r in records) {
      allPoints.addAll(r.points);
    }
    // 按时间排序 + 去重（同一毫秒只保留一个）
    allPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final dedup = <TrajectoryPoint>[];
    for (final p in allPoints) {
      if (dedup.isEmpty || dedup.last.timestamp != p.timestamp) {
        dedup.add(p);
      }
    }

    // 重新统计距离 / 海拔
    double distance = 0;
    double ascent = 0;
    double descent = 0;
    double? maxAlt;
    double? minAlt;
    double? prevLat;
    double? prevLng;
    double? prevAlt;
    for (final p in dedup) {
      if (prevLat != null && prevLng != null) {
        final d = TrajectoryService.haversine(prevLat, prevLng, p.lat, p.lng);
        if (d >= _mergeMinMove) {
          distance += d;
          prevLat = p.lat;
          prevLng = p.lng;
        }
      } else {
        prevLat = p.lat;
        prevLng = p.lng;
      }
      if (p.altitude != null) {
        final alt = p.altitude!;
        maxAlt = maxAlt == null ? alt : (alt > maxAlt ? alt : maxAlt);
        minAlt = minAlt == null ? alt : (alt < minAlt ? alt : minAlt);
        if (prevAlt != null) {
          final diff = alt - prevAlt;
          if (diff.abs() > _mergeAltThreshold) {
            if (diff > 0) {
              ascent += diff;
            } else {
              descent += -diff;
            }
          }
        }
        prevAlt = alt;
      }
    }

    // 停留点合并并排序
    final stops = <StopPoint>[];
    for (final r in records) {
      stops.addAll(r.stops);
    }
    stops.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

    final startTime = records
        .map((r) => r.startTime)
        .reduce((a, b) => a < b ? a : b);
    final endTime =
        records.map((r) => r.endTime).reduce((a, b) => a > b ? a : b);
    final duration = ((endTime - startTime) ~/ 1000);
    final avgSpeed = duration > 0 ? (distance / duration * 3.6) : 0.0;

    // 城市取含城市信息的第一条
    final cityRecord = records.firstWhere(
      (r) => r.city != null && r.city!.isNotEmpty,
      orElse: () => records.first,
    );

    return TrajectoryRecord(
      id: AppStorage.generateId(),
      startTime: startTime,
      endTime: endTime,
      points: dedup,
      distance: distance,
      duration: duration,
      stops: stops,
      maxAltitude: maxAlt,
      minAltitude: minAlt,
      ascent: ascent,
      descent: descent,
      avgSpeed: avgSpeed,
      title: '合并轨迹（${records.length} 条）',
      city: cityRecord.city,
    );
  }

  // ============================================================
  // 回读：GPX 字符串 → 多条轨迹（为外部文件导入合并预留）
  // ============================================================

  /// 解析 GPX 文本为本地轨迹记录列表。
  ///
  /// 支持：
  ///  - 多个 `<trk>`，每个 `<trk>` 解析为一条 [TrajectoryRecord]；
  ///  - 每条 `<trk>` 下所有 `<trkseg>` 的点合并；
  ///  - 解析 `<trkpt>` 的 lat/lon、`<ele>`、`<time>`、`<speed>`、`<course>`
  ///    以及 mt:accuracy 自定义扩展。
  ///
  /// 注意：这是面向「本项目导出格式」的轻量解析（正则实现，
  /// 无外部 xml 依赖）。如需严格兼容任意 GPX 文件，建议后续
  /// 引入 xml 解析包并替换本实现。
  static List<TrajectoryRecord> parseGpx(String content) {
    final records = <TrajectoryRecord>[];

    // 拆分每个 <trk>...</trk>
    final trkRe = RegExp(r'<trk>(.*?)</trk>', dotAll: true);
    final trkMatches = trkRe.allMatches(content);

    int index = 0;
    for (final trkM in trkMatches) {
      final trkBody = trkM.group(1) ?? '';
      final name = _firstAttr(trkBody, r'<name>(.*?)</name>') ??
          '导入轨迹 ${index + 1}';
      // 读取自定义扩展字段（mt: 命名空间）
      final city = _firstAttr(trkBody, r'<mt:city>(.*?)</mt:city>');
      final note = _firstAttr(trkBody, r'<mt:note>(.*?)</mt:note>');
      final points = _parseTrkpts(trkBody);
      if (points.isEmpty) continue;

      // 统计
      double distance = 0;
      double ascent = 0;
      double descent = 0;
      double? maxAlt;
      double? minAlt;
      double? prevLat;
      double? prevLng;
      double? prevAlt;
      for (final p in points) {
        if (prevLat != null && prevLng != null) {
          distance += TrajectoryService.haversine(
              prevLat, prevLng, p.lat, p.lng);
          prevLat = p.lat;
          prevLng = p.lng;
        } else {
          prevLat = p.lat;
          prevLng = p.lng;
        }
        if (p.altitude != null) {
          final alt = p.altitude!;
          maxAlt = maxAlt == null ? alt : (alt > maxAlt ? alt : maxAlt);
          minAlt = minAlt == null ? alt : (alt < minAlt ? alt : minAlt);
          if (prevAlt != null) {
            final diff = alt - prevAlt;
            if (diff.abs() > _mergeAltThreshold) {
              if (diff > 0) {
                ascent += diff;
              } else {
                descent += -diff;
              }
            }
          }
          prevAlt = alt;
        }
      }

      final startTime = points.first.timestamp;
      final endTime = points.last.timestamp;
      final duration = ((endTime - startTime) ~/ 1000);
      final avgSpeed = duration > 0 ? (distance / duration * 3.6) : 0.0;

      records.add(TrajectoryRecord(
        id: AppStorage.generateId(),
        startTime: startTime,
        endTime: endTime,
        points: points,
        distance: distance,
        duration: duration,
        stops: const [],
        maxAltitude: maxAlt,
        minAltitude: minAlt,
        ascent: ascent,
        descent: descent,
        avgSpeed: avgSpeed,
        title: name,
        city: city,
        note: note,
      ));
      index++;
    }

    return records;
  }

  // ---- 内部：解析单个 <trk> 内所有 <trkpt> ----

  static List<TrajectoryPoint> _parseTrkpts(String trkBody) {
    final points = <TrajectoryPoint>[];
    final ptRe = RegExp(
        r'<trkpt\s+lat="([-\d.]+)"\s+lon="([-\d.]+)"\s*>(.*?)</trkpt>',
        dotAll: true);
    for (final m in ptRe.allMatches(trkBody)) {
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (lat == null || lng == null) continue;
      final inner = m.group(3) ?? '';

      final ele = _firstDouble(inner, r'<ele>(.*?)</ele>');
      final timeStr = _firstAttr(inner, r'<time>(.*?)</time>');
      final speed = _firstDouble(inner, r'<speed>(.*?)</speed>');
      final course = _firstDouble(inner, r'<course>(.*?)</course>');
      final accuracy = _firstDouble(inner, r'<mt:accuracy>(.*?)</mt:accuracy>');

      int timestamp;
      if (timeStr != null) {
        final dt = DateTime.tryParse(timeStr);
        timestamp = dt?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch;
      } else {
        timestamp = DateTime.now().millisecondsSinceEpoch;
      }

      points.add(TrajectoryPoint(
        lat: lat,
        lng: lng,
        timestamp: timestamp,
        altitude: ele,
        speed: speed,
        accuracy: accuracy,
        heading: course,
      ));
    }
    return points;
  }

  // ============================================================
  // 内部：GPX 拼装辅助
  // ============================================================

  /// 组装完整 GPX 文档外壳
  static String _wrapGpx({
    required String metadataName,
    int? metadataTime,
    required String body,
  }) {
    final time = metadataTime != null
        ? '\n    <time>${_isoUtc(metadataTime)}</time>'
        : '';
    return '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="微旅途 MicroTrip"
     xmlns="http://www.topografix.com/GPX/1/1"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xmlns:mt="$_ns"
     xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata>
    <name>${_xml(metadataName)}</name>$time
  </metadata>$body
</gpx>
''';
  }

  /// 组装一个 `<trkseg>`（可选地携带本段名称注释）
  static String _buildTrkseg(List<TrajectoryPoint> points, {String? name}) {
    final comment = name != null ? '\n      <!-- $name -->' : '';
    final pts = points.map(_buildTrkpt).join('\n      ');
    return '    <trkseg>$comment\n      $pts\n    </trkseg>';
  }

  /// 组装一个 `<trkpt>`
  static String _buildTrkpt(TrajectoryPoint p) {
    final ele = p.altitude != null ? '\n        <ele>${p.altitude!.toStringAsFixed(1)}</ele>' : '';
    final time = '\n        <time>${_isoUtc(p.timestamp)}</time>';
    final speed = p.speed != null ? '\n        <speed>${p.speed!.toStringAsFixed(2)}</speed>' : '';
    final course = p.heading != null ? '\n        <course>${p.heading!.toStringAsFixed(1)}</course>' : '';
    final acc = p.accuracy != null
        ? '\n        <mt:accuracy>${p.accuracy!.toStringAsFixed(1)}</mt:accuracy>'
        : '';
    return '<trkpt lat="${p.lat.toStringAsFixed(7)}" lon="${p.lng.toStringAsFixed(7)}">$ele$time$speed$course$acc\n      </trkpt>';
  }

  /// 轨迹级扩展信息（自定义字段，便于回读时还原）
  static String _extensions(TrajectoryRecord r) => '''
    <extensions>
      <mt:id>${_xml(r.id)}</mt:id>
      <mt:city>${_xml(r.city ?? '')}</mt:city>
      <mt:note>${_xml(r.note ?? '')}</mt:note>
    </extensions>''';

  // ============================================================
  // 内部：文本 / 时间 / 正则辅助
  // ============================================================

  /// XML 转义（防止标题/备注里的特殊字符破坏文档）
  static String _xml(String? s) {
    if (s == null || s.isEmpty) return '';
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// 毫秒时间戳 → ISO8601 UTC（GPX 规范要求 UTC）
  static String _isoUtc(int ts) =>
      DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toIso8601String();

  /// 取正则第一组（用于解析 `<name>`...`</name>` 等）
  static String? _firstAttr(String source, String pattern) {
    final m = RegExp(pattern, dotAll: true).firstMatch(source);
    return m?.group(1)?.trim();
  }

  /// 取正则第一组并转为 double
  static double? _firstDouble(String source, String pattern) {
    final s = _firstAttr(source, pattern);
    if (s == null) return null;
    return double.tryParse(s);
  }
}
