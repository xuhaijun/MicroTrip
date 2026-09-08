import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../models/trajectory.dart';
import '../core/storage/app_storage.dart';

/// ============================================================
/// 轨迹录制服务（Phase 2 核心）
///
/// 功能：
///  1. GPS 流式订阅 — 实时采集经纬度/海拔/速度
///  2. Haversine 距离 — 逐点计算累计距离
///  3. 停留点检测 — 滑动窗口算法（半径 R 内停留 T 分钟）
///  4. 爬升统计 — 逐点海拔差累计
///  5. 状态管理 — recording / paused / stopped
///
/// 对应小程序 subpackages/travel/utils/trajectoryRecorder.js
/// ============================================================
class TrajectoryService {
  TrajectoryService._();

  // ---- 停留点检测参数（可配置） ----
  /// 停留点半径（米）：GPS 点在该半径内连续停留即触发
  static const double stopRadius = 100.0;
  /// 最小停留时长（秒）：超出才标记为停留点
  static const int stopMinDuration = 600; // 10 分钟
  /// 最小位移阈值（米）：小于此值视为 GPS 噪声，不计距离
  static const double minMoveThreshold = 5.0;
  /// 海拔变化阈值（米）：超过此值才计入爬升/下降
  static const double altChangeThreshold = 1.0;

  // ---- GPS 采样配置 ----
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // 每 10 米采样一次（省电 + 精度平衡）
  );

  // ---- 录制状态 ----
  static StreamSubscription<Position>? _subscription;
  static bool _isRecording = false;
  static bool _isPaused = false;

  // ---- 实时数据缓存 ----
  static final List<TrajectoryPoint> _points = [];
  static double _totalDistance = 0;
  static int _startTime = 0;
  static int _endTime = 0;
  static double? _prevLat;
  static double? _prevLng;
  static double? _prevAlt;
  static double _maxAlt = -double.infinity;
  static double _minAlt = double.infinity;
  static double _ascent = 0;
  static double _descent = 0;

  // ---- 停留点检测缓存 ----
  /// 当前候选停留点的起始索引
  static int? _stopCandidateStart;
  /// 候选停留点的质心
  static double _stopCenterLat = 0;
  static double _stopCenterLng = 0;
  /// 候选停留点内的点数
  static int _stopPointCount = 0;

  /// 实时状态回调（供 Provider 更新 UI）
  static void Function(TrajectoryStats stats)? onStatsUpdate;

  /// 是否正在录制
  static bool get isRecording => _isRecording;
  static bool get isPaused => _isPaused;

  /// 开始录制
  static Future<bool> start() async {
    if (_isRecording) return false;

    // 检查定位权限
    final ok = await _ensurePermission();
    if (!ok) return false;

    // 重置状态
    _points.clear();
    _totalDistance = 0;
    _startTime = DateTime.now().millisecondsSinceEpoch;
    _endTime = _startTime;
    _prevLat = null;
    _prevLng = null;
    _prevAlt = null;
    _maxAlt = -double.infinity;
    _minAlt = double.infinity;
    _ascent = 0;
    _descent = 0;
    _stopCandidateStart = null;
    _stopPointCount = 0;
    _isRecording = true;
    _isPaused = false;

    // 订阅 GPS 流
    _subscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(_onPositionUpdate);

    return true;
  }

  /// 暂停录制（保留已采集数据，但不再采集新点）
  static void pause() {
    _isPaused = true;
  }

  /// 恢复录制
  static void resume() {
    _isPaused = false;
  }

  /// 停止录制并返回完整轨迹
  static Future<TrajectoryRecord?> stop({String? title, String? city}) async {
    if (!_isRecording) return null;

    await _subscription?.cancel();
    _subscription = null;
    _isRecording = false;
    _isPaused = false;
    _endTime = DateTime.now().millisecondsSinceEpoch;

    if (_points.isEmpty) return null;

    // 完成停留点检测
    final stops = _detectStops();
    final duration = (_endTime - _startTime) ~/ 1000;
    final avgSpeed = duration > 0
        ? (_totalDistance / duration * 3.6) // m/s → km/h
        : 0.0;

    final record = TrajectoryRecord(
      id: AppStorage.generateId(),
      startTime: _startTime,
      endTime: _endTime,
      points: List.from(_points),
      distance: _totalDistance,
      duration: duration,
      stops: stops,
      maxAltitude: _maxAlt == -double.infinity ? null : _maxAlt,
      minAltitude: _minAlt == double.infinity ? null : _minAlt,
      ascent: _ascent,
      descent: _descent,
      avgSpeed: avgSpeed,
      title: title,
      city: city,
    );

    _points.clear();
    return record;
  }

  /// GPS 采样回调
  static void _onPositionUpdate(Position position) {
    if (_isPaused) return;

    final point = TrajectoryPoint(
      lat: position.latitude,
      lng: position.longitude,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      altitude: position.altitude.isFinite ? position.altitude : null,
      speed: position.speed.isFinite && position.speed >= 0 ? position.speed : null,
      accuracy: position.accuracy.isFinite ? position.accuracy : null,
      heading: position.heading.isFinite ? position.heading : null,
    );

    _points.add(point);
    _updateStats(point);
    _checkStopCandidate(point);

    // 通知 UI 更新
    onStatsUpdate?.call(currentStats());
  }

  /// 更新累计统计
  static void _updateStats(TrajectoryPoint point) {
    // 距离（Haversine）
    if (_prevLat != null && _prevLng != null) {
      final d = haversine(_prevLat!, _prevLng!, point.lat, point.lng);
      if (d >= minMoveThreshold) {
        _totalDistance += d;
        _prevLat = point.lat;
        _prevLng = point.lng;
      }
      // 否则不更新 prev（视为噪声点）
    } else {
      _prevLat = point.lat;
      _prevLng = point.lng;
    }

    // 海拔统计
    if (point.altitude != null) {
      final alt = point.altitude!;
      if (alt > _maxAlt) _maxAlt = alt;
      if (alt < _minAlt) _minAlt = alt;
      if (_prevAlt != null) {
        final diff = alt - _prevAlt!;
        if (diff.abs() > altChangeThreshold) {
          if (diff > 0) {
            _ascent += diff;
          } else {
            _descent += -diff;
          }
        }
      }
      _prevAlt = alt;
    }
  }

  /// 停留点候选检测（滑动窗口算法）
  static void _checkStopCandidate(TrajectoryPoint point) {
    if (_stopCandidateStart == null) {
      // 开始新的候选
      _stopCandidateStart = _points.length - 1;
      _stopCenterLat = point.lat;
      _stopCenterLng = point.lng;
      _stopPointCount = 1;
    } else {
      // 检查当前点是否在候选停留点半径内
      final d = haversine(
        _stopCenterLat, _stopCenterLng,
        point.lat, point.lng,
      );
      if (d <= stopRadius) {
        // 在半径内，更新质心
        _stopPointCount++;
        _stopCenterLat = (_stopCenterLat * (_stopPointCount - 1) + point.lat) / _stopPointCount;
        _stopCenterLng = (_stopCenterLng * (_stopPointCount - 1) + point.lng) / _stopPointCount;
      } else {
        // 离开半径，检查停留时长是否达标
        _finalizeStopCandidate();
        // 重置为新候选
        _stopCandidateStart = _points.length - 1;
        _stopCenterLat = point.lat;
        _stopCenterLng = point.lng;
        _stopPointCount = 1;
      }
    }
  }

  /// 完成当前停留点候选（检查时长是否达标）
  static StopPoint? _finalizeStopCandidate() {
    if (_stopCandidateStart == null || _stopPointCount < 2) {
      _stopCandidateStart = null;
      _stopPointCount = 0;
      return null;
    }

    final startIdx = _stopCandidateStart!;
    final startTs = _points[startIdx].timestamp;
    final endTs = _points.last.timestamp;
    final dur = (endTs - startTs) ~/ 1000;

    if (dur >= stopMinDuration) {
      final stop = StopPoint(
        lat: _stopCenterLat,
        lng: _stopCenterLng,
        arrivalTime: startTs,
        departureTime: endTs,
        duration: dur,
        radius: stopRadius,
      );
      _stopCandidateStart = null;
      _stopPointCount = 0;
      return stop;
    }

    _stopCandidateStart = null;
    _stopPointCount = 0;
    return null;
  }

  /// 录制结束时遍历所有候选，生成停留点列表
  static List<StopPoint> _detectStops() {
    final stops = <StopPoint>[];

    // 简化版：扫描所有点，找出满足条件的连续段
    if (_points.length < 2) return stops;

    int i = 0;
    while (i < _points.length) {
      int j = i + 1;
      double sumLat = _points[i].lat;
      double sumLng = _points[i].lng;
      int count = 1;

      while (j < _points.length) {
        final d = haversine(
          sumLat / count, sumLng / count,
          _points[j].lat, _points[j].lng,
        );
        if (d <= stopRadius) {
          sumLat += _points[j].lat;
          sumLng += _points[j].lng;
          count++;
          j++;
        } else {
          break;
        }
      }

      if (count >= 2) {
        final dur = (_points[j - 1].timestamp - _points[i].timestamp) ~/ 1000;
        if (dur >= stopMinDuration) {
          stops.add(StopPoint(
            lat: sumLat / count,
            lng: sumLng / count,
            arrivalTime: _points[i].timestamp,
            departureTime: _points[j - 1].timestamp,
            duration: dur,
            radius: stopRadius,
          ));
        }
      }
      i = j;
    }

    return stops;
  }

  /// 获取当前实时统计
  static TrajectoryStats currentStats() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final duration = _points.isNotEmpty ? (now - _startTime) ~/ 1000 : 0;
    final avgSpeed = duration > 0 ? (_totalDistance / duration * 3.6) : 0.0;
    return TrajectoryStats(
      points: List.unmodifiable(_points),
      distance: _totalDistance,
      duration: duration,
      avgSpeed: avgSpeed,
      maxAltitude: _maxAlt == -double.infinity ? null : _maxAlt,
      minAltitude: _minAlt == double.infinity ? null : _minAlt,
      ascent: _ascent,
      descent: _descent,
      pointCount: _points.length,
    );
  }

  /// 检查定位权限
  static Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  // ---- 工具方法 ----

  /// Haversine 公式：计算两点间球面距离（米）
  static double haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // 地球平均半径（米）
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;
}

/// 录制中实时统计快照（供 Provider 推送给 UI）
class TrajectoryStats {
  const TrajectoryStats({
    this.points = const [],
    this.distance = 0,
    this.duration = 0,
    this.avgSpeed = 0,
    this.maxAltitude,
    this.minAltitude,
    this.ascent = 0,
    this.descent = 0,
    this.pointCount = 0,
  });

  final List<TrajectoryPoint> points;
  final double distance;
  final int duration;
  final double avgSpeed;
  final double? maxAltitude;
  final double? minAltitude;
  final double ascent;
  final double descent;
  final int pointCount;

  String get distanceText {
    if (distance >= 1000) return '${(distance / 1000).toStringAsFixed(2)} km';
    return '${distance.round()} m';
  }

  String get durationText {
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    final s = duration % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get avgSpeedText => '${avgSpeed.toStringAsFixed(1)} km/h';
}
