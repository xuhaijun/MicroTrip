import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../core/config/data_config.dart';
import '../core/storage/app_storage.dart';
import '../models/ai_message.dart';
import '../models/city_info.dart';
import '../models/cloud_stats.dart';
import '../models/food_item.dart';
import '../models/memo_item.dart';
import '../models/scenery_item.dart';
import '../models/step_data.dart';
import '../models/trajectory.dart';
import '../models/weather.dart';
import '../services/ai_service.dart';
import '../services/background_recorder_service.dart';
import '../services/food_service.dart';
import '../services/ios_background_location.dart';
import '../services/location_service.dart';
import '../services/memo_repository.dart';
import '../services/scenery_service.dart';
import '../services/step_service.dart';
import '../services/sync_service.dart';
import '../services/trajectory_repository.dart';
import '../services/trajectory_service.dart';
import '../services/weather_service.dart';
import '../models/favorite_item.dart';
import '../services/favorite_repository.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_provider.dart';

/// ============================================================
/// Riverpod 状态层
/// 按业务域拆分：城市 / 天气 / AI 会话 / 备忘
/// ============================================================

// ==================== 当前城市 ====================

/// 当前选中城市（持久化到 travel_currentCity，默认成都）
class CityNotifier extends Notifier<CityInfo> {
  @override
  CityInfo build() {
    final raw = AppStorage.getObject(AppStorage.kCurrentCity);
    if (raw is Map) return CityInfo.fromMap(Map<String, dynamic>.from(raw));
    return CityInfo(name: '成都', province: '四川', lat: 30.57, lng: 104.07);
  }

  /// 切换城市：持久化 + 加入最近城市
  Future<void> switchCity(CityInfo city) async {
    state = city;
    await AppStorage.setObject(AppStorage.kCurrentCity, city.toMap());
    await LocationService.addRecentCity(city);
  }
}

final cityProvider = NotifierProvider<CityNotifier, CityInfo>(CityNotifier.new);

/// 最近城市列表
final recentCitiesProvider =
    FutureProvider<List<CityInfo>>((ref) => LocationService.loadRecentCities());

/// 定位当前城市（一次性动作，用 FutureProvider 自动管理加载态）
final locateProvider = FutureProvider<CityInfo?>((ref) async {
  final city = await LocationService.locateCity();
  return city;
});

// ==================== 天气 ====================

/// 天气聚合状态：实时 + 10 天预报 + 出行建议
class WeatherViewState {
  const WeatherViewState({
    this.now,
    this.daily = const [],
    this.loading = false,
    this.error,
  });

  final WeatherNow? now;
  final List<WeatherDaily> daily;
  final bool loading;
  final String? error;

  WeatherViewState copyWith({
    WeatherNow? now,
    List<WeatherDaily>? daily,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      WeatherViewState(
        now: now ?? this.now,
        daily: daily ?? this.daily,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class WeatherNotifier extends FamilyNotifier<WeatherViewState, CityInfo> {
  @override
  WeatherViewState build(CityInfo city) => const WeatherViewState();

  /// 拉取实时天气 + 预报（[force] 跳过缓存）
  Future<void> load(CityInfo city, {bool force = false}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      if (force) await WeatherService.clearCache(city);
      final now = await WeatherService.getNowWeather(city);
      state = state.copyWith(now: now, loading: false);
      // 预报异步补充（首页只展示前 3 天，失败不阻塞）
      final daily = await WeatherService.getForecast(city);
      state = state.copyWith(daily: daily, loading: false);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }
}

final weatherProvider = NotifierProviderFamily<WeatherNotifier, WeatherViewState,
    CityInfo>(WeatherNotifier.new);

// ==================== AI 会话 ====================

/// 小途聊天状态：历史消息 + 发送中标记
class AiChatState {
  const AiChatState({this.messages = const [], this.sending = false});
  final List<AiMessage> messages;
  final bool sending;

  AiChatState copyWith({List<AiMessage>? messages, bool? sending}) =>
      AiChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
      );
}

class AiChatNotifier extends Notifier<AiChatState> {
  static const int maxHistory = 20; // 保留最近 20 条上下文

  @override
  AiChatState build() {
    final raw = AppStorage.getObject(AppStorage.kAiChatHistory, defaultValue: []);
    if (raw is List) {
      final msgs = raw
          .map((e) => AiMessage.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      return AiChatState(messages: msgs);
    }
    return const AiChatState();
  }

  /// 发送用户消息并获取小途回复
  Future<void> send(String content) async {
    if (content.trim().isEmpty || state.sending) return;
    final userMsg = AiMessage(role: 'user', content: content.trim());
    state = state.copyWith(messages: [...state.messages, userMsg], sending: true);
    await _persist();

    try {
      // 上下文：截取最近 maxHistory 条
      final ctx = state.messages.length > maxHistory
          ? state.messages.sublist(state.messages.length - maxHistory)
          : state.messages;
      final reply = await AiService.chat(ctx);
      state = state.copyWith(
        messages: [...state.messages, AiMessage(role: 'assistant', content: reply)],
        sending: false,
      );
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          AiMessage(role: 'assistant', content: '抱歉，出小差了：$e\n请稍后再试～'),
        ],
        sending: false,
      );
    }
    await _persist();
  }

  Future<void> clear() async {
    state = const AiChatState();
    await AppStorage.remove(AppStorage.kAiChatHistory);
  }

  Future<void> _persist() async {
    await AppStorage.setObject(AppStorage.kAiChatHistory,
        state.messages.map((m) => m.toMap()).toList());
  }
}

final aiChatProvider =
    NotifierProvider<AiChatNotifier, AiChatState>(AiChatNotifier.new);

// ==================== 备忘 ====================

class MemoNotifier extends Notifier<List<MemoItem>> {
  @override
  List<MemoItem> build() {
    // 初始化异步加载（build 保持同步返回，load 中更新 state）
    Future.microtask(load);
    return [];
  }

  Future<void> load() async {
    state = await MemoRepository.loadAll();
  }

  Future<void> save(MemoItem item) async {
    await MemoRepository.save(item);
    await load();
  }

  Future<void> remove(String id) async {
    await MemoRepository.remove(id);
    await load();
  }

  Future<void> toggle(MemoItem item) async {
    await MemoRepository.toggleComplete(item.id, !item.completed);
    await load();
  }
}

final memoProvider = NotifierProvider<MemoNotifier, List<MemoItem>>(MemoNotifier.new);

// ==================== 出行建议（派生） ====================

final weatherAdviceProvider = Provider<List<WeatherAdvice>>((ref) {
  final city = ref.watch(cityProvider);
  final w = ref.watch(weatherProvider(city)).now;
  if (w == null) return const [];
  return WeatherUtils.adviceOf(w);
});

// ============================================================
// Phase 2: 轨迹录制 / 步数 / 拍照识物
// ============================================================

// ==================== 轨迹录制（实时） ====================

/// 轨迹录制状态
enum RecordingStatus { idle, recording, paused, stopped }

/// 录制中实时状态
class TrajectoryRecordingState {
  const TrajectoryRecordingState({
    this.status = RecordingStatus.idle,
    this.stats = const TrajectoryStats(),
  });

  final RecordingStatus status;
  final TrajectoryStats stats;

  TrajectoryRecordingState copyWith({
    RecordingStatus? status,
    TrajectoryStats? stats,
  }) =>
      TrajectoryRecordingState(
        status: status ?? this.status,
        stats: stats ?? this.stats,
      );
}

class TrajectoryRecordingNotifier
    extends Notifier<TrajectoryRecordingState> {
  @override
  TrajectoryRecordingState build() {
    // 注册回调：GPS 每次采样时更新 state
    TrajectoryService.onStatsUpdate = (stats) {
      if (state.status == RecordingStatus.recording) {
        state = state.copyWith(stats: stats);
      }
    };
    return const TrajectoryRecordingState();
  }

  /// 开始录制
  Future<bool> start() async {
    final ok = await TrajectoryService.start();
    if (ok) {
      state = state.copyWith(status: RecordingStatus.recording);
      // Phase 5：启动前台保活服务（Android 常驻通知 + 防杀），退后台 GPS 不断
      unawaited(BackgroundRecorderService.start());
      // iOS 后台轨迹：启用系统级后台定位（原生 BackgroundLocationManager），
      // 与 Android 前台服务并列；非 iOS 平台在 IosBackgroundLocation 内部安全忽略。
      // 开始录制时启一次后台定位 + 提交一次 BGTask 后台刷新，确保 App 退到后台仍持续采样。
      unawaited(IosBackgroundLocation.start());
      unawaited(IosBackgroundLocation.scheduleBackgroundRefresh());
    }
    return ok;
  }

  /// 暂停
  void pause() {
    TrajectoryService.pause();
    state = state.copyWith(status: RecordingStatus.paused);
  }

  /// 恢复
  void resume() {
    TrajectoryService.resume();
    state = state.copyWith(status: RecordingStatus.recording);
  }

  /// 停止录制并保存
  Future<TrajectoryRecord?> stop({String? title, String? city}) async {
    // Phase 5：先停前台保活服务（移除常驻通知，释放后台定位）
    unawaited(BackgroundRecorderService.stop());
    // iOS 后台轨迹：停止系统级后台定位（非 iOS 安全忽略）
    unawaited(IosBackgroundLocation.stop());
    final record = await TrajectoryService.stop(title: title, city: city);
    state = state.copyWith(status: RecordingStatus.stopped);
    if (record != null) {
      await TrajectoryRepository.save(record);
      // 刷新历史列表
      ref.invalidate(trajectoryHistoryProvider);
    }
    // 重置为 idle
    state = const TrajectoryRecordingState();
    return record;
  }
}

final trajectoryRecordingProvider = NotifierProvider<
    TrajectoryRecordingNotifier, TrajectoryRecordingState>(
    TrajectoryRecordingNotifier.new);

// ==================== 轨迹历史列表 ====================

class TrajectoryHistoryNotifier extends AsyncNotifier<List<TrajectoryRecord>> {
  @override
  Future<List<TrajectoryRecord>> build() => TrajectoryRepository.loadAll();

  Future<void> refresh() async {
    // 刷新时保留上一次数据：避免下拉刷新瞬间整片列表被全屏 loading 替换（大片空白）。
    // copyWithPrevious 让 state 在 loading/error 期间仍持有 .value（旧列表），页面据此继续渲染。
    final prev = state;
    state = const AsyncValue<List<TrajectoryRecord>>.loading()
        .copyWithPrevious(prev);
    try {
      final data = await TrajectoryRepository.loadAll();
      state = AsyncValue<List<TrajectoryRecord>>.data(data);
    } catch (e, st) {
      state = AsyncValue<List<TrajectoryRecord>>.error(e, st)
          .copyWithPrevious(prev);
    }
  }

  Future<void> delete(String id) async {
    await TrajectoryRepository.remove(id);
    state = await AsyncValue.guard(() => TrajectoryRepository.loadAll());
  }

  Future<void> updateRecord(TrajectoryRecord record) async {
    await TrajectoryRepository.save(record);
    state = await AsyncValue.guard(() => TrajectoryRepository.loadAll());
  }
}

final trajectoryHistoryProvider = AsyncNotifierProvider<
    TrajectoryHistoryNotifier, List<TrajectoryRecord>>(
    TrajectoryHistoryNotifier.new);

/// 单条轨迹详情
final trajectoryDetailProvider =
    FutureProvider.family<TrajectoryRecord?, String>(
  (ref, id) => TrajectoryRepository.getById(id),
);

// ==================== 云端足迹统计 ====================

/// 云端轨迹汇总统计（「我的」页「云端足迹」卡片）。
///
/// 几个刻意的设计选择：
///  - **watch authProvider**：登录/退出后自动重取，不需要页面手动 invalidate。
///    退出登录时 [SyncService.isConfigured] 变 false，直接返回空统计而非抛错，
///    避免"退出登录瞬间卡片闪一下红色错误"。
///  - **不自动重试**：统计失败不阻塞页面其他部分，由用户在卡片上手动点重试。
///  - 返回 [CloudStats.empty] 而非抛错来表达"没有数据"，
///    只有真正的网络/鉴权失败才走 error 分支。
final cloudStatsProvider = FutureProvider<CloudStats>((ref) async {
  // 依赖登录态：token 变化（登录/退出/切换账号）后自动重新拉取
  final auth = ref.watch(authProvider);
  if (!auth.isLoggedIn || !SyncService.isConfigured) {
    return CloudStats.empty;
  }
  return SyncService.fetchStats();
});

// ==================== 步数 ====================

class StepNotifier extends AsyncNotifier<StepData> {
  @override
  Future<StepData> build() => StepService.getTodaySteps();

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => StepService.getTodaySteps());
  }

  /// Phase 4：从传感器更新步数
  Future<void> updateFromSensor(int steps) async {
    await StepService.updateTodaySteps(steps);
    state = await AsyncValue.guard(() => StepService.getTodaySteps());
  }
}

final stepProvider =
    AsyncNotifierProvider<StepNotifier, StepData>(StepNotifier.new);

/// 最近 7 天步数（统计图表用）
final recentStepsProvider = FutureProvider<List<StepData>>(
  (ref) => StepService.getRecentSteps(days: 7),
);

// ============================================================
// 数据源开关（模拟数据总开关）
// ============================================================

/// 模拟数据开关：true=本地示例数据；false=服务端真实数据
/// 设置页切换时更新 state 并持久化；页面通过 ref.watch 自动重载。
final useMockDataProvider =
    StateProvider<bool>((ref) => DataConfig.useMockData);

// ============================================================
// 美景（服务端 / 模拟，依据开关切换）
// ============================================================

typedef SceneryQuery = ({String city, bool mock});

/// 景点列表（已注入开关参数，切换开关即自动重新拉取）
final sceneryListProvider = FutureProvider.family<
    SceneryResult<List<SceneryItem>>, SceneryQuery>(
  (ref, q) => SceneryService.fetchList(q.city, mock: q.mock),
);

/// 景点详情
final sceneryDetailProvider = FutureProvider.family<
    SceneryResult<SceneryItem>, ({int id, String city, bool mock})>(
  (ref, q) => SceneryService.fetchDetail(q.id, q.city, mock: q.mock),
);

/// 周边推荐
final sceneryNearbyProvider = FutureProvider.family<
    SceneryResult<List<NearbyScenery>>, ({int id, String city, bool mock})>(
  (ref, q) => SceneryService.fetchNearby(q.id, q.city, mock: q.mock),
);

// ============================================================
// 美食（服务端 / 模拟，依据开关切换）
// ============================================================

typedef FoodQuery = ({String city, bool mock});

/// 美食列表
final foodListProvider = FutureProvider.family<
    FoodResult<List<FoodItem>>, FoodQuery>(
  (ref, q) => FoodService.fetchList(q.city, mock: q.mock),
);

/// 美食详情
final foodDetailProvider = FutureProvider.family<
    FoodResult<FoodItem>, ({int id, String city, bool mock})>(
  (ref, q) => FoodService.fetchDetail(q.id, q.city, mock: q.mock),
);

/// 推荐门店（详情页「去哪吃」；同样按开关切换 服务端 / 本地示例）
final foodShopsProvider = FutureProvider.family<
    FoodResult<List<FoodShop>>, FoodQuery>(
  (ref, q) => FoodService.fetchShops(q.city, mock: q.mock),
);

// ============================================================
// 首页 / 我的页增强（对齐小程序：海拔 / 每日提示 / 收藏数 / 自动定位）
// ============================================================

/// 当前海拔（米）状态管理。
/// 定位策略区分两种场景：
/// - 初始加载（首页首帧 / 详情页进入）：优先读系统缓存定位（getLastKnownPosition），
///   秒回、省电，UI 快速出值；
/// - 手动刷新（详情页右上角 / 下拉刷新）：忽略缓存，强制 GPS 重新定位
///   （getCurrentPosition），获取最新海拔。
/// 未授权 / 失败返回 null（UI 降级展示「未授权定位权限」）。
class AltitudeNotifier extends AsyncNotifier<double?> {
  @override
  Future<double?> build() => _locate(forceFresh: false);

  /// 强制刷新：清空旧值进入 loading，再走 GPS 重新定位。
  /// 详情页右上角刷新按钮 / 下拉刷新调用；期间 UI 显示「定位中…」反馈。
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _locate(forceFresh: true));
  }

  Future<double?> _locate({required bool forceFresh}) async {
    try {
      if (!await LocationService.ensurePermission()) return null;
      // 统一 8 秒超时兜底：模拟器/室内 GPS 信号弱时 getCurrentPosition 可能
      // 长时间不回调，避免首页「定位中…」永久卡住。
      final pos = forceFresh
          ? await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.low),
            ).timeout(const Duration(seconds: 8))
          : (await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition(
                locationSettings:
                    const LocationSettings(accuracy: LocationAccuracy.low),
              ).timeout(const Duration(seconds: 8)));
      return pos.altitude;
    } catch (_) {
      return null;
    }
  }
}

final altitudeProvider =
    AsyncNotifierProvider<AltitudeNotifier, double?>(AltitudeNotifier.new);

/// 每日提示：按年内第几天轮换，离线可用（无需网络）
final dailyTipProvider = Provider<String>((ref) {
  const tips = <String>[
    '出门前看一眼天气，带好雨具更安心 ☔',
    '提前下载离线地图，信号弱也不迷路 🗺️',
    '把必备证件拍照存档，丢失也能快速补办 🪪',
    '景点门票错峰预约，避开人流高峰 ⛰️',
    '当地特色小吃，记得问问老板招牌菜 🍜',
    '长途自驾前检查胎压与油量，安全第一位 🚗',
    '给手机充好电、带好充电宝，导航不断电 🔋',
    '随身带支笔，填表登记快人一步 🖊️',
    '高海拔地区放慢脚步，预防高原反应 🏔️',
    '旅行保险买一份，遇事不慌 🛡️',
    '把行程发给家人，报平安更放心 📩',
    '轻装出行，留点空间装回忆 🎒',
  ];
  final now = DateTime.now();
  final start = DateTime(now.year, 1, 1);
  final dayOfYear = now.difference(start).inDays;
  return tips[dayOfYear % tips.length];
});

/// 收藏总数（美食 + 美景），用于「我的」页统计
final favoritesCountProvider = FutureProvider<int>((ref) async {
  final food = await FavoriteRepository.loadAll(FavoriteType.food);
  final scenery = await FavoriteRepository.loadAll(FavoriteType.scenery);
  return food.length + scenery.length;
});

/// 自动定位开关（持久化到 travel_autoLocate，默认开）
class AutoLocateNotifier extends Notifier<bool> {
  @override
  bool build() => AppStorage.getBool('autoLocate', defaultValue: true);

  Future<void> set(bool value) async {
    state = value;
    await AppStorage.setBool('autoLocate', value);
  }
}

final autoLocateProvider =
    NotifierProvider<AutoLocateNotifier, bool>(AutoLocateNotifier.new);
