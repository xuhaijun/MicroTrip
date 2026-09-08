import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../core/geo/cached_tile_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/trajectory.dart';

/// ============================================================
/// 轨迹地图组件（flutter_map 封装）
///
/// 功能：
///  - 天地图瓦片渲染（vec_w 矢量底图 + cva_w 注记，Web 墨卡托）
///  - 轨迹 Polyline 绘制（主色渐变）
///  - 停留点 Marker 标记
///  - 起点/终点标记
///  - 自动适配轨迹范围（fitBounds）
///
/// 天地图为 CGCS2000 坐标系，与 WGS-84 基本重合，坐标无需偏移转换。
/// ============================================================
class TrajectoryMapWidget extends StatefulWidget {
  const TrajectoryMapWidget({
    super.key,
    this.points = const [],
    this.stops = const [],
    this.initialCenter,
    this.initialZoom = 14,
    this.fitBounds = true,
    this.interactive = true,
    this.height,
    this.showControls = true,
  });

  /// 轨迹采样点列表
  final List<TrajectoryPoint> points;

  /// 停留点列表
  final List<StopPoint> stops;

  /// 地图初始中心点（无轨迹时使用）
  final LatLng? initialCenter;

  /// 初始缩放级别
  final double initialZoom;

  /// 是否自动适配轨迹范围
  final bool fitBounds;

  /// 是否可交互（缩放/拖动）
  final bool interactive;

  /// 固定高度（null = 撑满父容器）
  final double? height;

  /// 是否显示缩放控件
  final bool showControls;

  @override
  State<TrajectoryMapWidget> createState() => TrajectoryMapWidgetState();
}

class TrajectoryMapWidgetState extends State<TrajectoryMapWidget> {
  final MapController _mapController = MapController();

  // 天地图瓦片（CGCS2000≈WGS-84）+ 磁盘缓存：弱网/断网时曾浏览区域仍可显示。
  // 每个 State 持有独立实例，避免路由销毁时 dispose 误关其它地图的 client。
  final CachedNetworkTileProvider _tileProvider =
      CachedNetworkTileProvider(silenceExceptions: true);

  @override
  void initState() {
    super.initState();
    // 异步拿到缓存目录后开启磁盘缓存（未拿到前自动降级为纯网络）
    getTemporaryDirectory().then((d) {
      if (mounted) _tileProvider.setCacheDir('${d.path}/map_tiles');
    });
  }

  @override
  void didUpdateWidget(covariant TrajectoryMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新点到达时自动 fitBounds
    if (widget.fitBounds &&
        widget.points.length > oldWidget.points.length &&
        widget.points.length >= 2) {
      _fitToBounds();
    }
  }

  /// 适配轨迹范围
  void _fitToBounds() {
    if (widget.points.length < 2) return;
    final lats = widget.points.map((p) => p.lat).toList();
    final lngs = widget.points.map((p) => p.lng).toList();
    final south = lats.reduce((a, b) => a < b ? a : b);
    final north = lats.reduce((a, b) => a > b ? a : b);
    final west = lngs.reduce((a, b) => a < b ? a : b);
    final east = lngs.reduce((a, b) => a > b ? a : b);

    // 增加边距
    final padLat = (north - south) * 0.15 + 0.001;
    final padLng = (east - west) * 0.15 + 0.001;
    // 天地图为 Web 墨卡托(≈WGS-84)，边界直接用原始坐标，无需 GCJ-02 转换
    final padded = LatLngBounds(
      LatLng(south - padLat, west - padLng),
      LatLng(north + padLat, east + padLng),
    );

    _mapController.fitCamera(CameraFit.bounds(
      bounds: padded,
      maxZoom: 16,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasPoints = widget.points.length >= 2;
    final center = widget.initialCenter ??
        (widget.points.isNotEmpty
            ? LatLng(widget.points.first.lat, widget.points.first.lng)
            : const LatLng(30.57, 104.07)); // 默认成都
    final zoom = hasPoints ? 14.0 : widget.initialZoom;

    final mapWidget = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        // 天地图为 CGCS2000≈WGS-84，与 App 坐标一致，直接喂原始坐标即可
        initialCenter: center,
        initialZoom: zoom,
      ),
      children: [
        // 瓦片层：天地图（vec_w 矢量底图 + cva_w 注记）。Web 墨卡托(≈WGS-84)，
        // 本 App 坐标可直接显示，无需 GCJ-02 转换；必须带 tk（见 app_config）。
        TileLayer(
          urlTemplate: AppConfig.tdtVecUrl,
          subdomains: AppConfig.tdtSubdomains,
          userAgentPackageName: 'com.xuhai.micro_trip',
          tileProvider: _tileProvider,
        ),
        TileLayer(
          urlTemplate: AppConfig.tdtCvaUrl,
          subdomains: AppConfig.tdtSubdomains,
          userAgentPackageName: 'com.xuhai.micro_trip',
          tileProvider: _tileProvider,
        ),
        // 轨迹线
        if (hasPoints)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.points
                    .map((p) => LatLng(p.lat, p.lng))
                    .toList(),
                color: AppColors.primary,
                strokeWidth: 4,
              ),
            ],
          ),
        // 停留点标记
        if (widget.stops.isNotEmpty)
          MarkerLayer(
            markers: widget.stops.map((s) {
              return Marker(
                point: LatLng(s.lat, s.lng),
                width: 40,
                height: 40,
                child: _StopMarker(stop: s),
              );
            }).toList(),
          ),
        // 起点终点
        if (hasPoints) ...[
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(widget.points.first.lat, widget.points.first.lng),
                width: 30,
                height: 30,
                child: _EndpointMarker(
                  color: Colors.green,
                  label: '起',
                ),
              ),
              Marker(
                point: LatLng(widget.points.last.lat, widget.points.last.lng),
                width: 30,
                height: 30,
                child: _EndpointMarker(
                  color: Colors.red,
                  label: '终',
                ),
              ),
            ],
          ),
        ],
      ],
    );

    final content = Stack(
      children: [
        // 不可交互时用 AbsorbPointer 阻止手势
        if (widget.interactive)
          mapWidget
        else
          AbsorbPointer(child: mapWidget),
        // 缩放控件
        if (widget.showControls && widget.interactive)
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.add,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                ),
                const SizedBox(height: 4),
                _ZoomButton(
                  icon: Icons.remove,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                ),
                const SizedBox(height: 4),
                _ZoomButton(
                  icon: Icons.center_focus_strong,
                  onTap: _fitToBounds,
                ),
              ],
            ),
          ),
      ],
    );

    if (widget.height != null) {
      return SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: content,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: content,
    );
  }
}

/// 停留点标记
class _StopMarker extends StatelessWidget {
  const _StopMarker({required this.stop});
  final StopPoint stop;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Center(
        child: Icon(Icons.pause_circle, color: Colors.white, size: 20),
      ),
    );
  }
}

/// 起点/终点标记
class _EndpointMarker extends StatelessWidget {
  const _EndpointMarker({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 缩放按钮
class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: AppColors.textDark),
      ),
    );
  }
}
