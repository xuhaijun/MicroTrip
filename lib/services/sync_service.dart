import 'package:dio/dio.dart';

import '../core/http/http_client.dart';
import '../core/storage/app_storage.dart';
import '../models/cloud_stats.dart';
import '../models/cloud_trajectory.dart';
import '../models/trajectory.dart';
import 'auth_service.dart';
import 'trajectory_repository.dart';

/// ============================================================
/// 轨迹云端同步服务（Phase 5）
///
/// 与 MicroTripServer（Node.js + Express + SQLite）对接：
///   POST   {apiBase}/trajectory/sync   { trajectory } → { ok, id }    按 id 幂等 upsert
///   GET    {apiBase}/trajectory/list   分页摘要（不含 GPS 点）→ { list, page, pageSize, total, hasMore }
///   GET    {apiBase}/trajectory/stats  汇总统计 → { count, totalDistance, totalDuration, ... }
///   GET    {apiBase}/trajectory/:id    完整详情 → { trajectory }
///   DELETE {apiBase}/trajectory/:id    删除云端记录 → { ok: true }
///
/// 所有接口需要 `Authorization: Bearer <token>`（needAuth: true）。
/// 优雅降级：未配置后端地址 / 未登录时，isConfigured = false，
/// UI 层据此隐藏同步入口或给出引导提示，App 本体功能不受影响。
///
/// 对外 API（供设置页 / 云端历史页 / 我的页使用）：
///  - isConfigured / lastSyncAtText       同步状态查询
///  - syncAll({onProgress})               手动全量同步
///  - fetchList({page, pageSize})         云端历史列表（分页）
///  - fetchStats()                        云端汇总统计（SQL 侧聚合）
///  - fetchDetail(id)                     云端完整详情 → TrajectoryRecord
///  - deleteRemote(id)                    删除云端记录
/// ============================================================
class SyncService {
  SyncService._();

  /// 上次同步时间戳存储键（travel_ 前缀由 AppStorage 自动加）
  static const String kLastSyncAt = 'lastSyncAt';

  // ==================== 状态查询 ====================

  /// 是否可同步：已配置后端地址 && 已登录 && 且必须是**云端账号**（loginType == 'server'）。
  ///
  /// 为什么要卡 `loginType`：本地演示账号（体验用户）虽然 `isLoggedIn` 为 true，
  /// 但它没有服务端凭据，请求云端接口必然鉴权失败。若不卡这一层，
  /// 「我的」页云端足迹卡片会在本地账号下被判定为「已配置」而弹出「获取失败」。
  static bool get isConfigured =>
      AuthService.serverUrl.isNotEmpty &&
      AuthService.isLoggedIn &&
      AuthService.currentUser?.loginType == 'server';

  /// 上次同步时间描述（"从未同步" / "今天 10:05" / "8/19 10:05"）
  static String get lastSyncAtText {
    final raw = AppStorage.getObject(kLastSyncAt);
    final ts = raw is num ? raw.toInt() : 0;
    if (ts <= 0) return '从未同步';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) return '今天 $hm';
    return '${d.month}/${d.day} $hm';
  }

  // ==================== 全量同步 ====================

  /// 把本地全部轨迹逐条 POST 到云端（按 id 幂等，可重复执行）。
  /// [onProgress] 每同步一条回调一次 (已完成数, 总数)，供进度 UI 使用。
  /// 成功则记录 [kLastSyncAt] 并返回统计结果；单条失败不中断整体流程。
  static Future<SyncResult> syncAll({
    void Function(int done, int total)? onProgress,
  }) async {
    if (!isConfigured) {
      throw ServiceException('未登录或未配置后端地址，无法同步');
    }

    final records = await TrajectoryRepository.loadAll();
    final total = records.length;
    var synced = 0;
    final errors = <String>[];

    for (var i = 0; i < total; i++) {
      final r = records[i];
      try {
        final data = await HttpClient.post(
          '${AuthService.apiBase}/trajectory/sync',
          body: {'trajectory': r.toMap()},
          needAuth: true,
        );
        // 后端返回 { ok: true, id }；仅当显式失败才记错误
        final ok = _unwrap(data)?['ok'];
        if (ok != true) {
          errors.add('${r.displayTitle}: 服务端返回异常');
        } else {
          synced++;
        }
      } catch (e) {
        errors.add('${r.displayTitle}: ${_extractMessage(e)}');
      }
      onProgress?.call(i + 1, total);
    }

    // 只要发起过同步就记录时间（即使部分失败，便于用户判断上次尝试）
    await AppStorage.setObject(kLastSyncAt, DateTime.now().millisecondsSinceEpoch);
    return SyncResult(
      total: total,
      synced: synced,
      failed: errors.length,
      errors: errors,
    );
  }

  // ==================== 云端历史列表（分页） ====================

  /// 拉取云端轨迹摘要列表（不含 GPS 点，省流量）
  static Future<CloudTrajectoryPageData> fetchList({
    int page = 1,
    int pageSize = 20,
  }) async {
    if (!isConfigured) {
      throw ServiceException('未登录或未配置后端地址');
    }
    final data = await HttpClient.get(
      '${AuthService.apiBase}/trajectory/list',
      query: {'page': page, 'pageSize': pageSize},
      needAuth: true,
    );
    final body = _unwrap(data);
    if (body is! Map) {
      throw ServiceException('云端返回格式错误');
    }
    final listRaw = body['list'];
    if (listRaw is! List) {
      throw ServiceException('云端返回格式错误（缺少 list）');
    }
    return CloudTrajectoryPageData(
      list: listRaw
          .map((e) => CloudTrajectory.fromMap(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      page: (body['page'] as num?)?.toInt() ?? page,
      pageSize: (body['pageSize'] as num?)?.toInt() ?? pageSize,
      total: (body['total'] as num?)?.toInt() ?? 0,
      hasMore: body['hasMore'] == true,
    );
  }

  // ==================== 云端汇总统计 ====================

  /// 拉取云端轨迹汇总统计（轨迹数 / 累计里程时长 / 爬升下降 / 采样点数）。
  ///
  /// 服务端在 SQL 侧一次聚合后只回传一行，因此**调用代价与轨迹条数无关**；
  /// 「我的」页据此展示云端足迹，无需把全部轨迹拉到本地求和。
  ///
  /// 永不返回 null：无数据时返回 [CloudStats.empty]，UI 无需处理 null 分支。
  static Future<CloudStats> fetchStats() async {
    if (!isConfigured) {
      throw ServiceException('未登录或未配置后端地址');
    }
    final data = await HttpClient.get(
      '${AuthService.apiBase}/trajectory/stats',
      needAuth: true,
    );
    final body = _unwrap(data);
    if (body is! Map) {
      throw ServiceException('云端返回格式错误（stats 非对象）');
    }
    return CloudStats.fromMap(Map<String, dynamic>.from(body));
  }

  // ==================== 云端详情 ====================

  /// 拉取云端完整轨迹详情并转换为本地 TrajectoryRecord
  /// （字段名与后端 detail 接口对齐，可无缝渲染地图与统计）
  static Future<TrajectoryRecord> fetchDetail(String id) async {
    if (!isConfigured) {
      throw ServiceException('未登录或未配置后端地址');
    }
    final data = await HttpClient.get(
      '${AuthService.apiBase}/trajectory/$id',
      needAuth: true,
    );
    final body = _unwrap(data);
    final traj = body is Map ? body['trajectory'] : null;
    if (traj is! Map) {
      throw ServiceException('云端返回格式错误（缺少 trajectory）');
    }
    return TrajectoryRecord.fromMap(Map<String, dynamic>.from(traj));
  }

  // ==================== 云端删除 ====================

  /// 删除云端轨迹记录（不影响本地数据）
  static Future<void> deleteRemote(String id) async {
    if (!isConfigured) {
      throw ServiceException('未登录或未配置后端地址');
    }
    final data = await HttpClient.delete(
      '${AuthService.apiBase}/trajectory/$id',
      needAuth: true,
    );
    final ok = _unwrap(data)?['ok'];
    if (ok != true) {
      throw ServiceException('删除失败');
    }
  }

  // ==================== 内部辅助 ====================

  /// 兼容 {data: ...} 包裹与平铺两种响应结构
  static dynamic _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) return data['data'];
    return data;
  }

  /// 从异常中提取可读的错误信息（优先后端 {error:{message}} / {message}）
  static String _extractMessage(Object e) {
    if (e is ServiceException) {
      final detail = e.detail;
      if (detail is DioException) {
        final resp = detail.response?.data;
        if (resp is Map) {
          final err = resp['error'];
          if (err is Map && err['message'] != null) {
            return err['message'].toString();
          }
          if (resp['message'] != null) return resp['message'].toString();
        }
      }
      return e.message;
    }
    return e.toString();
  }
}

/// 一次同步的统计结果
class SyncResult {
  const SyncResult({
    required this.total,
    required this.synced,
    required this.failed,
    required this.errors,
  });

  /// 本地轨迹总数
  final int total;
  /// 同步成功条数
  final int synced;
  /// 同步失败条数
  final int failed;
  /// 失败明细（"标题: 原因"）
  final List<String> errors;
}
