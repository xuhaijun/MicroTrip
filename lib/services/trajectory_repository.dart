import '../core/storage/app_storage.dart';
import '../models/trajectory.dart';

/// ============================================================
/// 轨迹仓库 — 持久化轨迹记录到本地存储
///
/// 使用 shared_preferences（与小程序 storage 模型一致），
/// 存储键 travel_trajectories，值为 List<Map>。
///
/// Phase 4 可无缝迁移到 SQLite / 后端 API。
/// ============================================================
class TrajectoryRepository {
  TrajectoryRepository._();

  static const _key = 'travel_trajectories';

  /// 加载所有历史轨迹（按时间倒序）
  static Future<List<TrajectoryRecord>> loadAll() async {
    final raw = AppStorage.getObject(_key, defaultValue: []);
    if (raw is! List) return [];
    return raw
        .map((e) => TrajectoryRecord.fromMap(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// 保存单条轨迹（新增或更新）
  static Future<void> save(TrajectoryRecord record) async {
    final list = await loadAll();
    final idx = list.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      list[idx] = record;
    } else {
      list.insert(0, record);
    }
    await _persist(list);
  }

  /// 删除单条轨迹
  static Future<void> remove(String id) async {
    final list = await loadAll();
    list.removeWhere((r) => r.id == id);
    await _persist(list);
  }

  /// 清空所有轨迹
  static Future<void> clear() async {
    await AppStorage.remove(_key);
  }

  /// 获取单条轨迹
  static Future<TrajectoryRecord?> getById(String id) async {
    final list = await loadAll();
    for (final r in list) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// 轨迹总数
  static Future<int> count() async {
    final list = await loadAll();
    return list.length;
  }

  /// 总距离（米）
  static Future<double> totalDistance() async {
    final list = await loadAll();
    return list.fold<double>(0.0, (sum, r) => sum + r.distance);
  }

  static Future<void> _persist(List<TrajectoryRecord> list) async {
    await AppStorage.setObject(
      _key,
      list.map((r) => r.toMap()).toList(),
    );
  }
}
