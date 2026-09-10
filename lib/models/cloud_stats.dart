/// ============================================================
/// 云端轨迹汇总统计（GET /trajectory/stats）
///
/// 由服务端在 SQL 侧一次聚合（COUNT / SUM / MAX），只回传一行，
/// 客户端无需把全部轨迹拉下来在本地求和 —— 这是本模型存在的主要理由：
/// 轨迹数据量随使用时间线性增长，本地求和迟早会拖慢「我的」页。
///
/// 单位与服务端契约保持**原样一致**（刻意不在服务端换算，避免歧义）：
///  - [totalDistance] / [maxDistance] / [totalAscent] / [totalDescent] 单位 **米**
///  - [totalDuration] 单位 **秒**
///  - 时间戳均为**毫秒**
/// 换算与展示统一由本类的 `xxxText` 负责。
///
/// 与本地数据的关系：本统计覆盖**云端**轨迹（可能包含其他设备同步上来的），
/// 因此它与本地记录数不一致是正常现象，UI 上需明确标注「云端」。
/// ============================================================
class CloudStats {
  const CloudStats({
    required this.count,
    required this.totalDistance,
    required this.totalDuration,
    required this.totalAscent,
    required this.totalDescent,
    this.maxDistance,
    this.maxAvgSpeed,
    this.firstStart,
    this.lastStart,
    this.lastSyncedAt,
    required this.totalPoints,
  });

  /// 云端轨迹总数
  final int count;

  /// 累计里程（米）
  final double totalDistance;

  /// 累计时长（秒）
  final int totalDuration;

  /// 累计爬升（米）
  final double totalAscent;

  /// 累计下降（米）
  final double totalDescent;

  /// 单条最长里程（米）；无轨迹时为 null
  final double? maxDistance;

  /// 单条最高平均速度；无数据时为 null
  final double? maxAvgSpeed;

  /// 最早一条轨迹的开始时间（毫秒）；无轨迹时为 null
  final int? firstStart;

  /// 最近一条轨迹的开始时间（毫秒）；无轨迹时为 null
  final int? lastStart;

  /// 最近一次同步时间（毫秒）；从未同步时为 null
  final int? lastSyncedAt;

  /// 全部轨迹的 GPS 采样点总数
  final int totalPoints;

  /// 空统计（未登录 / 无数据时的安全默认值）
  static const CloudStats empty = CloudStats(
    count: 0,
    totalDistance: 0,
    totalDuration: 0,
    totalAscent: 0,
    totalDescent: 0,
    totalPoints: 0,
  );

  bool get isEmpty => count == 0;

  // ==================== 解析 ====================

  /// 从服务端 JSON 构造。
  ///
  /// 容错策略：数值字段缺失/为 null 一律按 0 处理，**不抛异常** ——
  /// 统计卡片属于「锦上添花」的信息，不能因为某个字段缺失就让整页报错。
  factory CloudStats.fromMap(Map<String, dynamic> m) {
    return CloudStats(
      count: _int(m['count']),
      totalDistance: _double(m['totalDistance']),
      totalDuration: _int(m['totalDuration']),
      totalAscent: _double(m['totalAscent']),
      totalDescent: _double(m['totalDescent']),
      maxDistance: _doubleOrNull(m['maxDistance']),
      maxAvgSpeed: _doubleOrNull(m['maxAvgSpeed']),
      firstStart: _intOrNull(m['firstStart']),
      lastStart: _intOrNull(m['lastStart']),
      lastSyncedAt: _intOrNull(m['lastSyncedAt']),
      totalPoints: _int(m['totalPoints']),
    );
  }

  static int _int(dynamic v) => v is num ? v.toInt() : 0;
  static double _double(dynamic v) => v is num ? v.toDouble() : 0.0;
  static int? _intOrNull(dynamic v) => v is num ? v.toInt() : null;
  static double? _doubleOrNull(dynamic v) => v is num ? v.toDouble() : null;

  // ==================== 展示格式化 ====================

  /// 累计里程：12345 m → "12.3"（配合标题的「km」单位使用）。
  /// 不足 1 km 时保留 2 位小数（"0.85"），避免显示成 "0.0" 丢失信息。
  String get totalDistanceKmText {
    final km = totalDistance / 1000;
    return km >= 1 ? km.toStringAsFixed(1) : km.toStringAsFixed(2);
  }

  /// 累计时长的「小时」数值（保留 1 位小数）：90 分钟 → "1.5"
  String get totalDurationHourText =>
      (totalDuration / 3600).toStringAsFixed(1);

  /// 累计时长可读文本：'2 小时 30 分' / '45 分钟' / '0 分钟'
  String get totalDurationText {
    if (totalDuration <= 0) return '0 分钟';
    final h = totalDuration ~/ 3600;
    final m = (totalDuration % 3600) ~/ 60;
    if (h <= 0) return '$m 分钟';
    return m <= 0 ? '$h 小时' : '$h 小时 $m 分';
  }

  /// 累计爬升（米，取整）：1234.6 → "1235"
  String get totalAscentText => totalAscent.round().toString();

  /// 累计下降（米，取整）
  String get totalDescentText => totalDescent.round().toString();

  /// 采样点数（千分位）：12345 → "12,345"
  String get totalPointsText => _grouped(totalPoints);

  /// 轨迹数（千分位）
  String get countText => _grouped(count);

  /// 单条最长里程（米 → km 文本）
  String get maxDistanceText {
    final d = maxDistance;
    if (d == null || d <= 0) return '—';
    return '${(d / 1000).toStringAsFixed(1)} km';
  }

  /// 出行时间范围：'2026/03/15 — 2026/09/10'；无数据时 '—'
  String get rangeText {
    final a = firstStart;
    final b = lastStart;
    if (a == null && b == null) return '—';
    final from = a == null ? '—' : _dateText(a);
    final to = b == null ? '—' : _dateText(b);
    return '$from — $to';
  }

  /// 最近同步时间的相对文本（服务端时间戳，可能为 null）
  String get lastSyncedText => _relativeText(lastSyncedAt);

  /// 最近一次出行时间（今天 / 昨天 / 8/19）
  String get lastTripText => _relativeDayText(lastStart);

  /// 最近一次出行距今的天数；无数据返回 null
  int? get daysSinceLastTrip {
    final b = lastStart;
    if (b == null) return null;
    final d = DateTime.fromMillisecondsSinceEpoch(b);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
  }

  /// 统计与本地记录数的差异说明（云端可能含其他设备数据）
  String diffHint(int localCount) {
    if (count == localCount) return '与本地记录一致';
    if (count > localCount) return '比本地多 ${count - localCount} 条（含其他设备）';
    return '比本地少 ${localCount - count} 条（未同步）';
  }

  static String _grouped(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _dateText(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// 时间戳 → '从未同步' / '刚刚' / '12 分钟前' / '3 小时前' / '8/19'
  static String _relativeText(int? ms) {
    if (ms == null || ms <= 0) return '从未同步';
    final diff = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }

  /// 时间戳 → '今天' / '昨天' / '3 天前' / '8/19'
  static String _relativeDayText(int? ms) {
    if (ms == null || ms <= 0) return '暂无出行记录';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days <= 0) return '今天';
    if (days == 1) return '昨天';
    if (days < 30) return '$days 天前';
    return '${d.month}/${d.day}';
  }
}
