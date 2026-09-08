# 微旅途 Flutter 性能优化：启动加速 + 包体积瘦身

> 日期：2026-08-20 ｜ 范围：`main.dart` / `weather_push_service.dart` / `home_page.dart` / `build.gradle.kts` / `pubspec.yaml`
> 校验：`dart analyze lib` → **No issues found!**

---

## 一、启动慢根因与修复

### 根因 1：时区库同步解析阻塞首帧（主因）
`main.dart` 在 `runApp` 之前的事件循环里调用 `WeatherPushService.init()`，其内部
`tzdata.initializeTimeZones()` 会 **同步解析完整 IANA 时区数据库**（`latest_all`，约 1.8MB
以 base64 编入 Dart 源码），直接卡住首帧渲染 —— 这是「半天出不来」的头号原因。

**修复**：把 `WeatherPushService.init()` 与 `BackgroundRecorderService.configure()` 一并
挪到 `WidgetsBinding.instance.addPostFrameCallback` 中执行，等 **首帧绘制完成后再跑**，
彻底移出启动关键路径。即便内部仍有耗时，用户也已先看到界面。

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  unawaited(WeatherPushService.init());
  unawaited(BackgroundRecorderService.configure());
});
```

### 根因 2：首页启动即触发定位与健康授权
首页 `build` 里直接 `ref.watch(altitudeProvider)`（Geolocator GPS 定位）与
`ref.watch(stepProvider)`（Health Connect 步数授权），会让 App 一打开就发起定位并弹出
系统健康授权框，拉长/打断启动观感。

**修复**：移除这两个 provider 在 `build` 中的 watch，改为首帧后 `_loadSecondary()` 以
本地状态异步加载（界面先显示「定位中… / —」占位），下拉刷新 `_reload()` 同步
`invalidate` 并重拉。定位与健康授权因此不再出现在启动路上。

> 实现细节（2026-08 迭代后）：`altitudeProvider` / `stepProvider` 为 `AsyncNotifierProvider`，
> 首页不再「等待」provider 完成，而是 `_setupSecondaryListeners()` 用 `ref.listenManual(provider, cb,
> fireImmediately: true)` 监听状态，回调取 `valueOrNull` 写入本地字段（见 `home_page.dart`）。
> 外部等待 AsyncNotifier 无公开 API（`AsyncValue` 无 `future` getter），此监听模式是标准解法。

```dart
// initState 首帧后
WidgetsBinding.instance.addPostFrameCallback((_) {
  final city = ref.read(cityProvider);
  ref.read(weatherProvider(city).notifier).load(city);
  _loadSecondary(); // 海拔 + 步数，延后加载
});
```

---

## 二、包体积根因与修复

| 问题 | 修复 | 收益 |
|------|------|------|
| 时区库用 `latest_all`（全量 ~1.8MB） | 改 `latest_10y.dart`（±5 年，约 25%） | 包体 ↓ + 解析更快 |
| release 未开混淆/资源裁剪 | `isMinifyEnabled=true` + `isShrinkResources=true` | 移除未用代码/资源 |
| 未做 ABI 过滤（32+64 位 .so 全打） | 预留 `ndk { abiFilters += "arm64-v8a" }`（注释态） | 原生体积可再减半 |
| `cupertino_icons` 依赖但零引用 | 从 `pubspec.yaml` 删除 | 移除约 1.5MB 图标字体 |

> `build.gradle.kts` 中的 `abiFilters` 默认**注释**，因为本项目此前为规避 NDK 下载问题
> 移除了 `ndkVersion`。取消注释可再砍半原生体积，但需本地安装 NDK；更省事的等效方案是直接打
> **AAB**（Play 按设备分发所需 ABI，下载体积自然减半）。

---

## 三、推荐构建命令（在用户本机执行）

```bash
# 体积最优：App Bundle + 图标树摇（Play 按 ABI 分发，下载体积最小）
flutter build appbundle --release --tree-shake-icons

# 若只要单个 APK 且想再减半原生体积：先去 build.gradle.kts 取消注释 abiFilters arm64-v8a（需 NDK）
flutter build apk --release --tree-shake-icons

# iOS
flutter build ios --release --tree-shake-icons
```

**重要**：请用 **release** 构建测启动与体积。Debug 模式本身是 JIT、无 tree-shake、无混淆，
启动天然偏慢，不能代表真实表现。

---

## 四、可选增强（按需，本轮未做）

- **原生闪屏**：接入 `flutter_native_splash`，遮盖 Flutter 引擎初始化的空白期，进一步
  提升启动观感（ engines 初始化阶段目前是白/黑屏）。
- **iOS 体积**：交付由 App Store 做体积精简，命令如上。

---

## 五、遗留（与本轮无关，待确认）

- 此前「发现/行程页 overflowed-by-pixels 黄条」根因已定位：`FadeSlideIn` 进场动画
  `Transform.translate(+24)` 越界（`RenderTransform` 不扩展自身边界）。系统性解法是在
  `anim_effects.dart` 的 `FadeSlideIn` 动画未完成时用 `ClipRect` 裁剪（完成后移除以保留
  卡片阴影）。用户本轮转向性能，未实施，确认后可直接落地。
