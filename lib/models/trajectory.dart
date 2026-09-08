// ============================================================
// 轨迹数据模型（Phase 2）
//
// 对应小程序 subpackages/travel/pages/trajectory 的数据结构，
// 但在 Flutter 版中扩展了停留点检测、距离/爬升统计等能力。
// ============================================================

/// 单个 GPS 采样点
class TrajectoryPoint {
  TrajectoryPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.altitude,
    this.speed,
    this.accuracy,
    this.heading,
  });

  /// 纬度
  final double lat;
  /// 经度
  final double lng;
  /// 采样时间（毫秒时间戳）
  final int timestamp;
  /// 海拔（米），可能为 null（取决于设备 GPS 能力）
  final double? altitude;
  /// 瞬时速度（米/秒），可能为 null
  final double? speed;
  /// 定位精度（米），越小越精确
  final double? accuracy;
  /// 航向（度），0=正北，顺时针
  final double? heading;

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'ts': timestamp,
        'alt': altitude,
        'spd': speed,
        'acc': accuracy,
        'hdg': heading,
      };

  factory TrajectoryPoint.fromMap(Map<String, dynamic> m) => TrajectoryPoint(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        timestamp: (m['ts'] as num).toInt(),
        altitude: m['alt'] != null ? (m['alt'] as num).toDouble() : null,
        speed: m['spd'] != null ? (m['spd'] as num).toDouble() : null,
        accuracy: m['acc'] != null ? (m['acc'] as num).toDouble() : null,
        heading: m['hdg'] != null ? (m['hdg'] as num).toDouble() : null,
      );

  /// 转为 latlong2 的 LatLng（供 flutter_map 使用）
  double get latitude => lat;
  double get longitude => lng;
}

/// 停留点（Stop Point）
///
/// 算法：连续 GPS 点在半径 [radius] 米范围内停留超过 [minDuration] 秒，
/// 即标记为停留点。可用于后续自动生成「一日游攻略」中的景点推荐。
class StopPoint {
  StopPoint({
    required this.lat,
    required this.lng,
    required this.arrivalTime,
    required this.departureTime,
    required this.duration,
    this.radius = 100,
    this.label,
    this.address,
  });

  /// 停留中心纬度（所有停留点的质心）
  final double lat;
  /// 停留中心经度
  final double lng;
  /// 到达时间（毫秒时间戳）
  final int arrivalTime;
  /// 离开时间（毫秒时间戳）
  final int departureTime;
  /// 停留时长（秒）
  final int duration;
  /// 检测半径（米）
  final double radius;
  /// 用户自定义标签（如「天府广场」）
  final String? label;
  /// 逆地理地址（由 LocationService 填充）
  final String? address;

  /// 停留时长格式化（如 "1小时23分"）
  String get durationText {
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    if (h > 0) return '$h小时$m分';
    if (m > 0) return '$m分钟';
    return '$duration秒';
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'arr': arrivalTime,
        'dep': departureTime,
        'dur': duration,
        'rad': radius,
        'label': label,
        'addr': address,
      };

  factory StopPoint.fromMap(Map<String, dynamic> m) => StopPoint(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        arrivalTime: (m['arr'] as num).toInt(),
        departureTime: (m['dep'] as num).toInt(),
        duration: (m['dur'] as num).toInt(),
        radius: m['rad'] != null ? (m['rad'] as num).toDouble() : 100,
        label: m['label']?.toString(),
        address: m['addr']?.toString(),
      );
}

/// 完整轨迹记录
class TrajectoryRecord {
  TrajectoryRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.points,
    required this.distance,
    required this.duration,
    this.stops = const [],
    this.maxAltitude,
    this.minAltitude,
    this.ascent,
    this.descent,
    this.avgSpeed,
    this.title,
    this.note,
    this.city,
  });

  /// 唯一 ID
  final String id;
  /// 开始时间（毫秒时间戳）
  final int startTime;
  /// 结束时间（毫秒时间戳）
  final int endTime;
  /// 全部 GPS 采样点
  final List<TrajectoryPoint> points;
  /// 总距离（米）
  final double distance;
  /// 总时长（秒，含暂停时间）
  final int duration;
  /// 检测到的停留点
  final List<StopPoint> stops;
  /// 最高海拔（米）
  final double? maxAltitude;
  /// 最低海拔（米）
  final double? minAltitude;
  /// 累计爬升（米）
  final double? ascent;
  /// 累计下降（米）
  final double? descent;
  /// 平均速度（公里/小时）
  final double? avgSpeed;
  /// 轨迹标题（用户可编辑）
  final String? title;
  /// 轨迹备注
  final String? note;
  /// 所在城市
  final String? city;

  // ---- 格式化辅助 ----

  /// 距离格式化：1234m → "1.2 km"，500m → "500 m"
  String get distanceText {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.round()} m';
  }

  /// 时长格式化：3600s → "1小时0分"，120s → "2分钟"
  String get durationText {
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    if (h > 0) return '$h小时$m分';
    return '$m分钟';
  }

  /// 日期格式化：2026/8/19
  String get dateText {
    final d = DateTime.fromMillisecondsSinceEpoch(startTime);
    return '${d.year}/${d.month}/${d.day}';
  }

  /// 显示标题（无标题时用日期）
  String get displayTitle => title?.isNotEmpty == true ? title! : '轨迹 $dateText';

  Map<String, dynamic> toMap() => {
        'id': id,
        'start': startTime,
        'end': endTime,
        'pts': points.map((p) => p.toMap()).toList(),
        'distance': distance,
        'duration': duration,
        'stops': stops.map((s) => s.toMap()).toList(),
        'maxAlt': maxAltitude,
        'minAlt': minAltitude,
        'ascent': ascent,
        'descent': descent,
        'avgSpeed': avgSpeed,
        'title': title,
        'note': note,
        'city': city,
      };

  factory TrajectoryRecord.fromMap(Map<String, dynamic> m) => TrajectoryRecord(
        id: m['id'].toString(),
        startTime: (m['start'] as num).toInt(),
        endTime: (m['end'] as num).toInt(),
        points: (m['pts'] as List)
            .map((p) => TrajectoryPoint.fromMap(Map<String, dynamic>.from(p as Map)))
            .toList(),
        distance: _reqNum(m, 'distance', 'dist'),
        duration: _reqInt(m, 'duration', 'dur'),
        stops: m['stops'] != null
            ? (m['stops'] as List)
                .map((s) => StopPoint.fromMap(Map<String, dynamic>.from(s as Map)))
                .toList()
            : [],
        maxAltitude: m['maxAlt'] != null ? (m['maxAlt'] as num).toDouble() : null,
        minAltitude: m['minAlt'] != null ? (m['minAlt'] as num).toDouble() : null,
        ascent: _optNum(m, 'ascent', 'asc'),
        descent: _optNum(m, 'descent', 'desc'),
        avgSpeed: _optNum(m, 'avgSpeed', 'avgSpd'),
        title: m['title']?.toString(),
        note: m['note']?.toString(),
        city: m['city']?.toString(),
      );

  /// 创建副本并修改指定字段
  TrajectoryRecord copyWith({
    String? title,
    String? note,
    String? city,
  }) =>
      TrajectoryRecord(
        id: id,
        startTime: startTime,
        endTime: endTime,
        points: points,
        distance: distance,
        duration: duration,
        stops: stops,
        maxAltitude: maxAltitude,
        minAltitude: minAltitude,
        ascent: ascent,
        descent: descent,
        avgSpeed: avgSpeed,
        title: title ?? this.title,
        note: note ?? this.note,
        city: city ?? this.city,
      );

  // ---- 字段命名兼容辅助 ----
  // 服务端统一使用长名（distance/ascent/...）；旧版本本地持久化数据用短名
  // （dist/asc/...），这里优先读长名、回退短名，避免旧数据解析失败。
  static double _reqNum(Map<String, dynamic> m, String a, String b) =>
      ((m[a] ?? m[b]) as num).toDouble();
  static int _reqInt(Map<String, dynamic> m, String a, String b) =>
      ((m[a] ?? m[b]) as num).toInt();
  static double? _optNum(Map<String, dynamic> m, String a, String b) {
    final v = m[a] ?? m[b];
    return v != null ? (v as num).toDouble() : null;
  }
}
