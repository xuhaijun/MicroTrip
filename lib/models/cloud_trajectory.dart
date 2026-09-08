// ============================================================
// 云端轨迹摘要模型（Phase 5）
//
// 对应 MicroTripServer GET /trajectory/list 返回的列表项
// （不含 GPS 点，省流量）；点击后再用 GET /trajectory/:id
// 拉取完整详情并转换为 TrajectoryRecord 渲染地图。
// ============================================================

/// 云端轨迹摘要（列表页使用）
class CloudTrajectory {
  const CloudTrajectory({
    required this.id,
    required this.start,
    required this.end,
    required this.distance,
    required this.duration,
    this.avgSpeed,
    this.title,
    this.note,
    this.city,
    this.syncedAt,
  });

  /// 轨迹唯一 ID（与本地 TrajectoryRecord.id 同源）
  final String id;
  /// 开始时间（毫秒时间戳）
  final int start;
  /// 结束时间（毫秒时间戳）
  final int end;
  /// 总距离（米）
  final double distance;
  /// 总时长（秒）
  final int duration;
  /// 平均速度（公里/小时）
  final double? avgSpeed;
  /// 轨迹标题
  final String? title;
  /// 备注
  final String? note;
  /// 所在城市
  final String? city;
  /// 云端同步时间（毫秒时间戳）
  final int? syncedAt;

  // ---- 格式化辅助（与 TrajectoryRecord 对齐） ----

  /// 距离格式化：1234m → "1.2 km"，500m → "500 m"
  String get distanceText {
    if (distance >= 1000) return '${(distance / 1000).toStringAsFixed(1)} km';
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
    final d = DateTime.fromMillisecondsSinceEpoch(start);
    return '${d.year}/${d.month}/${d.day}';
  }

  /// 显示标题（无标题时用日期）
  String get displayTitle => title?.isNotEmpty == true ? title! : '轨迹 $dateText';

  /// 同步时间格式化："8/19 10:05"
  String get syncedAtText {
    if (syncedAt == null) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(syncedAt!);
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${d.month}/${d.day} $hm';
  }

  /// 解析后端列表项（字段名与 MicroTripServer list 接口一致）
  factory CloudTrajectory.fromMap(Map<String, dynamic> m) => CloudTrajectory(
        id: m['id'].toString(),
        start: (m['start'] as num).toInt(),
        end: (m['end'] as num).toInt(),
        distance: (m['distance'] as num).toDouble(),
        duration: (m['duration'] as num).toInt(),
        avgSpeed: m['avgSpeed'] != null ? (m['avgSpeed'] as num).toDouble() : null,
        title: m['title']?.toString(),
        note: m['note']?.toString(),
        city: m['city']?.toString(),
        syncedAt: m['syncedAt'] != null ? (m['syncedAt'] as num).toInt() : null,
      );
}

/// 云端轨迹列表分页结果（对应 GET /trajectory/list 响应）
class CloudTrajectoryPageData {
  const CloudTrajectoryPageData({
    required this.list,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });

  final List<CloudTrajectory> list;
  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;
}
