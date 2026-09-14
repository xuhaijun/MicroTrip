import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/config/app_config.dart';
import '../../core/geo/cached_tile_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/location_service.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 附近探索（对应小程序 subpackages/travel/pages/map/map.js）
/// 全屏地图展示「我的位置」，支持周边分类检索（景点 / 美食 / 酒店），
/// 点击 POI 在地图上聚焦并显示详情；可从美食/景点详情页带入聚焦坐标。
///
/// 地图瓦片：天地图（CGCS2000≈WGS-84，坐标无需偏移转换；弱网/已看区域可离线显示）。
/// 数据来源：景点 = sceneryListProvider；美食 = foodShopsProvider（含坐标）；
///           酒店 = 暂无服务端接口，使用当前位置周边的演示数据（明确标注）。
/// ============================================================

/// 地图聚焦参数（从美食/景点详情页「在附近查看 / 导航」带入）
class NearbyFocus {
  const NearbyFocus({
    required this.lat,
    required this.lng,
    this.name,
    this.type, // 'scenery' | 'food' | null
  });
  final double lat;
  final double lng;
  final String? name;
  final String? type;
}

/// 周边兴趣点（统一模型，便于地图标记 + 列表复用）
class _Poi {
  _Poi({
    required this.name,
    required this.lat,
    required this.lng,
    required this.category, // 'scenery' | 'food' | 'hotel'
    this.image = '',
    this.rating = 0,
    this.detailPath, // 点击「查看详情」跳转路径（可为 null）
  });
  final String name;
  final double lat;
  final double lng;
  final String category;
  final String image;
  final double rating;
  String distanceText = '';
  final String? detailPath;
}

/// 分类元信息（图标 / 文案 / 主题色）
class _CategoryMeta {
  const _CategoryMeta(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

const _kCategories = <String, _CategoryMeta>{
  'scenery': _CategoryMeta('景点', Icons.landscape, AppColors.primary),
  'food': _CategoryMeta('美食', Icons.restaurant, AppColors.accent),
  'hotel': _CategoryMeta('酒店', Icons.hotel, AppColors.success),
};

/// 底部 POI 列表容器高度。
/// 卡片 3 行内容（名称 / 分类标签 / 评分·距离）实测约 51（已给文本设固定行高，
/// 高度可预测），加上卡片内边距 20 与列表上下留白 20 → 96。
/// 取 100 留出余量：系统字体放大到 1.5 倍仍不溢出（原 116 时卡片中部留白过大）。
const double _kListHeight = 104;

class NearbyMapPage extends ConsumerStatefulWidget {
  const NearbyMapPage({super.key, this.initialFocus});

  /// 从详情页带入的聚焦坐标（门店/景点）
  final NearbyFocus? initialFocus;

  @override
  ConsumerState<NearbyMapPage> createState() => _NearbyMapPageState();
}

class _NearbyMapPageState extends ConsumerState<NearbyMapPage> {
  final MapController _mapController = MapController();

  // 天地图瓦片 + 磁盘缓存：弱网/已看区域读本地缓存，网络不可达时返回透明瓦片。
  // 每个 State 持有独立实例，避免路由销毁时 dispose 误关其它地图的 client。
  final CachedNetworkTileProvider _tileProvider =
      CachedNetworkTileProvider(silenceExceptions: true);

  /// 我的位置（定位成功后非空）
  LatLng? _myLocation;

  /// 当前选中分类
  String _category = '全部';

  /// 当前选中 POI 在「过滤后列表」中的索引
  int? _selectedIndex;

  /// 是否已尝试定位（避免重复弹窗）
  bool _locating = false;

  /// 分类页签顺序（含「全部」）
  static const _tabs = ['全部', '景点', '美食', '酒店'];

  @override
  void initState() {
    super.initState();
    // 异步拿到临时目录后开启瓦片磁盘缓存（弱网/已浏览区域离线可见）。
    getTemporaryDirectory().then((d) {
      if (mounted) _tileProvider.setCacheDir('${d.path}/map_tiles');
    });
    _locateMe();
  }

  /// 定位：成功则移动到我的位置；失败降级到城市中心
  Future<void> _locateMe() async {
    if (_locating) return;
    _locating = true;
    try {
      if (await LocationService.ensurePermission()) {
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.low),
            );
        if (mounted) {
          setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
          _flyTo(_myLocation!, 14);
        }
      }
    } catch (_) {
      // 权限拒绝 / 失败：保留城市中心，不阻断页面
    } finally {
      _locating = false;
    }
  }

  /// 地图中心点：聚焦坐标 > 我的位置 > 城市中心 > 成都默认
  LatLng get _center {
    if (widget.initialFocus != null) {
      return LatLng(widget.initialFocus!.lat, widget.initialFocus!.lng);
    }
    if (_myLocation != null) return _myLocation!;
    final city = ref.read(cityProvider);
    if (city.lat != 0 && city.lng != 0) return LatLng(city.lat, city.lng);
    return const LatLng(30.57, 104.07); // 成都
  }

  /// 相机移动：天地图为 CGCS2000≈WGS-84，与 App 坐标一致，直接移动即可。
  void _flyTo(LatLng target, double zoom) {
    _mapController.move(target, zoom);
  }

  /// 计算两点的公里/米文本（latlong2 内置大地线距离）
  String _distanceText(LatLng a, LatLng b) {
    final meters = const Distance().distance(a, b);
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  /// 收集周边 POI（景点 + 美食门店 + 演示酒店）
  List<_Poi> _collectPois(LatLng center) {
    final city = ref.read(cityProvider);
    final mock = ref.read(useMockDataProvider);
    final list = <_Poi>[];

    // ---- 景点（含坐标的条目）----
    final scenery = ref.watch(sceneryListProvider((city: city.name, mock: mock)));
    scenery.whenOrNull(data: (res) {
      for (final s in res.data) {
        if (s.latitude == 0 || s.longitude == 0) continue;
        list.add(_Poi(
          name: s.name,
          lat: s.latitude,
          lng: s.longitude,
          category: 'scenery',
          image: s.image,
          rating: s.rating,
          detailPath: '/scenery-detail/${s.id}',
        ));
      }
    });

    // ---- 美食门店（含坐标）----
    final shops = ref.watch(foodShopsProvider((city: city.name, mock: mock)));
    shops.whenOrNull(data: (res) {
      for (final sh in res.data) {
        if (sh.latitude == 0 || sh.longitude == 0) continue;
        list.add(_Poi(
          name: sh.name,
          lat: sh.latitude,
          lng: sh.longitude,
          category: 'food',
          rating: sh.rating,
          detailPath: '/food',
        ));
      }
    });

    // ---- 酒店（演示数据，围绕中心点生成）----
    const hotelNames = [
      '锦江宾馆',
      '如家精选酒店',
      '希尔顿花园酒店',
      '全季酒店',
      '亚朵酒店',
      '汉庭优佳',
    ];
    const hotelRatings = [4.7, 4.5, 4.8, 4.4, 4.6, 4.3];
    const offsets = [
      [0.006, 0.004],
      [-0.008, 0.007],
      [0.004, -0.009],
      [-0.005, -0.006],
      [0.009, 0.002],
      [-0.003, 0.008],
    ];
    for (var i = 0; i < hotelNames.length; i++) {
      list.add(_Poi(
        name: hotelNames[i],
        lat: center.latitude + offsets[i][0],
        lng: center.longitude + offsets[i][1],
        category: 'hotel',
        rating: hotelRatings[i],
      ));
    }

    // 距离文本（依赖我的位置；无则空）
    if (_myLocation != null) {
      for (final p in list) {
        p.distanceText = _distanceText(
          _myLocation!,
          LatLng(p.lat, p.lng),
        );
      }
    }
    return list;
  }

  /// 过滤后的 POI 列表（按分类）
  List<_Poi> _filtered(List<_Poi> all) => _category == '全部'
      ? all
      : all.where((p) => p.category == _category).toList();

  @override
  Widget build(BuildContext context) {
    final center = _center;
    final allPois = _collectPois(center);
    final pois = _filtered(allPois);

    // 选中索引越界保护
    if (_selectedIndex != null && _selectedIndex! >= pois.length) {
      _selectedIndex = null;
    }
    final selected = _selectedIndex != null ? pois[_selectedIndex!] : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: '附近探索',
            subtitle: ref.watch(cityProvider).displayName,
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: () => context.pop(),
              ),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                // ---------------- 地图 ----------------
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: widget.initialFocus != null ? 15 : 13,
                  ),
                  children: [
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
                    // 周边 POI 标记
                    MarkerLayer(
                      markers: [
                        for (var i = 0; i < pois.length; i++)
                          _poiMarker(pois[i], i == _selectedIndex, () {
                            setState(() => _selectedIndex = i);
                            _flyTo(LatLng(pois[i].lat, pois[i].lng), 15);
                          }),
                      ],
                    ),
                    // 我的位置
                    if (_myLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _myLocation!,
                            width: 46,
                            height: 46,
                            child: _MyLocationMarker(),
                          ),
                        ],
                      ),
                    // 详情页聚焦标记（高亮）
                    if (widget.initialFocus != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                                widget.initialFocus!.lat,
                                widget.initialFocus!.lng),
                            width: 44,
                            height: 44,
                            child: _FocusMarker(
                              label: widget.initialFocus!.name ?? '目标',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // ---------------- 分类筛选 ----------------
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      children: [
                        for (final tab in _tabs)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _category = tab;
                                _selectedIndex = null;
                              }),
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _category == tab
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                ),
                                child: Text(
                                  tab,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _category == tab
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // ---------------- 回到我的位置 ----------------
                Positioned(
                  right: 12,
                  bottom: _panelBottom(pois, selected) + 12,
                  child: _MapButton(
                    icon: Icons.my_location,
                    onTap: () {
                      if (_myLocation != null) {
                        _flyTo(_myLocation!, 14);
                      } else {
                        _locateMe();
                      }
                    },
                  ),
                ),
                // ---------------- 缩放控件 ----------------
                Positioned(
                  right: 12,
                  bottom: _panelBottom(pois, selected) + 64,
                  child: Column(
                    children: [
                      _MapButton(
                        icon: Icons.add,
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _MapButton(
                        icon: Icons.remove,
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        ),
                      ),
                    ],
                  ),
                ),
                // ---------------- 底部面板（选中详情 + 列表）----------------
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  // 文本缩放上限 1.2：底部卡片高度是固定值，系统大字体下
                  // 3 行内容会被撑出卡片（与万年历网格同一手法，2026-09-14）
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        (MediaQuery.of(context).textScaler.scale(16) / 16) > 1.2
                            ? 1.2
                            : (MediaQuery.of(context).textScaler.scale(16) / 16),
                      ),
                    ),
                    child: _BottomPanel(
                    category: _category,
                    pois: pois,
                    selected: selected,
                    onSelect: (i) {
                      setState(() => _selectedIndex = i);
                      _flyTo(LatLng(pois[i].lat, pois[i].lng), 15);
                    },
                    onCloseSelected: () => setState(() => _selectedIndex = null),
                    onOpenDetail: (poi) {
                      if (poi.detailPath != null) {
                        context.push(poi.detailPath!);
                      }
                    },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 底部面板需要预留的高度（用于定位按钮错位）
  double _panelBottom(List<_Poi> pois, _Poi? selected) {
    // 面板总高 = 底部留白 12 + 列表容器 _kListHeight
    //          + 选中详情卡（含 10 外边距，约 86 高，取 92 留余量）
    return 12 + _kListHeight + (selected != null ? 92 : 0);
  }

  /// POI 地图标记
  Marker _poiMarker(_Poi poi, bool active, VoidCallback onTap) {
    final meta = _kCategories[poi.category]!;
    return Marker(
      point: LatLng(poi.lat, poi.lng),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: meta.color.withValues(alpha: active ? 1 : 0.85),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: active ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: meta.color.withValues(alpha: 0.4),
                blurRadius: active ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(meta.icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

/// 我的位置标记（蓝色脉冲点）
class _MyLocationMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      );
}

/// 详情页聚焦标记（橙色高亮旗标）
class _FocusMarker extends StatelessWidget {
  const _FocusMarker({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadius.round),
              boxShadow: AppShadows.card,
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.location_on,
              color: AppColors.accent, size: 22),
        ],
      );
}

/// 圆形地图按钮（缩放 / 定位）
class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: AppShadows.card,
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      );
}

/// 底部面板：选中详情卡 + 横向 POI 列表
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.category,
    required this.pois,
    required this.selected,
    required this.onSelect,
    required this.onCloseSelected,
    required this.onOpenDetail,
  });
  final String category;
  final List<_Poi> pois;
  final _Poi? selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onCloseSelected;
  final ValueChanged<_Poi> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 选中详情卡
        if (selected != null)
          FadeSlideIn(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                children: [
                  _CategoryIcon(category: selected!.category, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selected!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: AppColors.warning),
                            const SizedBox(width: 2),
                            Text(selected!.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            if (selected!.distanceText.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.near_me,
                                  size: 13, color: AppColors.textHint),
                              const SizedBox(width: 2),
                              Text(selected!.distanceText,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (selected!.detailPath != null)
                    TextButton(
                      onPressed: () => onOpenDetail(selected!),
                      child: const Text('详情',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.primary)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: AppColors.textHint),
                    onPressed: onCloseSelected,
                  ),
                ],
              ),
            ),
          ),
        // 横向列表
        Container(
          height: _kListHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: pois.isEmpty
              ? const Center(
                  child: Text('该分类暂无周边数据',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textHint)),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 10),
                  itemCount: pois.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10), // ignore: unnecessary_underscores
                  itemBuilder: (_, i) {
                    final p = pois[i];
                    final meta = _kCategories[p.category]!;
                    final active = selected != null && selected == p;
                    return GestureDetector(
                      onTap: () => onSelect(i),
                      child: Container(
                        width: 150,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primaryLight.withValues(alpha: 0.12)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          // 选中态加粗描边，扫一眼就能锁定当前项
                          border: Border.all(
                            color: active
                                ? AppColors.primary
                                : AppColors.border,
                            width: active ? 1.4 : 1,
                          ),
                        ),
                        // 3 行紧凑排布（名称 / 分类标签 / 评分·距离）：
                        // 1. 去掉原来的 Spacer——它在卡片中部撑出一大块空白，且名称只剩一行宽度；
                        // 2. 补上「分类」文字标签——按「全部」筛选时只靠图标认不出类型；
                        // 3. 名称独占一行，长名字能多显示几个字。
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                // 固定行高：中文默认行高随系统字体浮动，
                                // 固定后才能算准卡片高度、避免溢出（实测曾溢出 7px）
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: meta.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(meta.label,
                                  style: TextStyle(
                                      fontSize: 10,
                                      height: 1.1,
                                      fontWeight: FontWeight.w600,
                                      color: meta.color)),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 12, color: AppColors.warning),
                                const SizedBox(width: 2),
                                Text(p.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        height: 1.2,
                                        color: AppColors.textSecondary)),
                                const Spacer(),
                                if (p.distanceText.isNotEmpty) ...[
                                  const Icon(Icons.near_me,
                                      size: 11, color: AppColors.textHint),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(p.distanceText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            height: 1.2,
                                            color: AppColors.textHint)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 分类小图标（emoji / 图标）
class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category, this.size = 20});
  final String category;
  final double size;
  @override
  Widget build(BuildContext context) {
    final meta = _kCategories[category]!;
    return Icon(meta.icon, size: size, color: meta.color);
  }
}
