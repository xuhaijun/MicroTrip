# iOS 真机后台轨迹录制 — Mac 落地清单

> 对应功能：App 退到后台 / 锁屏时仍持续记录 GPS 轨迹。
> 代码层（Dart + Swift + plist）已在 Windows 侧完成并核对闭环；本文件只列 **Mac/Xcode 物理步骤**，拿到 Mac 后照做即可。

---

## 0. 已完成（代码侧，无需 Mac）

| 层 | 文件 | 作用 |
|----|------|------|
| Dart 桥接 | `lib/services/ios_background_location.dart` | `MethodChannel('microtrip/location')`；`start()`/`stop()`/`scheduleBackgroundRefresh()`，非 iOS 安全忽略 |
| Dart 接入 | `lib/providers/app_providers.dart` `TrajectoryRecordingNotifier` | `start()` 并行调 `start()+scheduleBackgroundRefresh()`；`stop()` 并行调 `stop()`（与 Android 前台服务并列） |
| 原生通道 | `ios/Runner/AppDelegate.swift` | 注册 MethodChannel，三处理器映射到原生 `start()/stop()/setupBGTask()+scheduleRefresh()` |
| 原生管理 | `ios/Runner/BackgroundLocationManager.swift` | `allowsBackgroundLocationUpdates=true`、`requestAlwaysAuthorization()`、`didUpdateLocations` 回调、BGTask 链式续订 |
| 配置 | `ios/Runner/Info.plist` | `UIBackgroundModes(location/fetch)` + `BGTaskSchedulerPermittedIdentifiers(com.microtrip.backgroundRefresh)` + 定位权限描述 |

> 录制页 `trajectory_record_page.dart` 通过 `trajectoryRecordingProvider.notifier` 启停，故「开始录制自动启后台、结束自动停」已生效。

---

## 1. Xcode 开启后台能力（必做）

1. 打开 `ios/Runner.xcworkspace`（用 Xcode，勿用 `.xcodeproj`）。
2. 选中 **Runner → Signing & Capabilities**：
   - 点 **+ Capability** → 添加 **Background Modes**，勾选：
     - ☑ **Location updates**
     - ☑ **Background fetch**
   - 同一页确认 **Signing** 已选 Apple 开发者账号、Bundle ID 正确。
3. 前往 [Apple Developer 后台](https://developer.apple.com/account/resources/identifiers) 对应 App ID：
   - 启用 **Background Modes**（勾 Location updates / Background fetch 后 Save）。
   - 若后续用健康步数，一并开启 **HealthKit**（否则 `health` 读步数会崩）。

> 若只在 Xcode 勾了 Capability 但后台 App ID 没开，真机运行会报权限/能力不匹配。

---

## 2. 构建与真机联调

```bash
# 在 Mac 上，项目根目录
flutter pub get
flutter build ios        # 或 flutter build ipa（归档上架）
# 选真机设备 → Run（▶）
```

真机验证清单：
- [ ] 进入「轨迹录制」→ 点「开始录制」，系统弹**始终允许**定位 → 选「始终」。
- [ ] 按 Home/上滑**退到后台**，观察状态栏出现**蓝色箭头/蓝条**（表示后台定位活跃）。
- [ ] 后台放置数分钟，再回前台「停止录制」→ 轨迹点数应持续累积（非仅前台段）。
- [ ] 控制台无 `BGTask 提交失败`、无定位授权报错。

---

## 3. 上架

1. 真机联调通过后：`flutter build ipa`。
2. Xcode → **Product → Archive** → 上传 **App Store Connect**。
3. 在 App Store Connect 建应用、填隐私答复（定位用途）、上传截图。
4. 提交审核；后台定位类功能需在审核备注说明用途，避免被拒。

---

## 4. 可选增强（按需，仍属原生侧）

- **原生直接落库**：当前设计由 Flutter 侧 `TrajectoryService`（geolocator）采点，原生仅「保活」。
  若要求 iOS 在 Flutter 引擎挂起后仍采点，可在
  `BackgroundLocationManager.didUpdateLocations` 批量缓存到本地（SQLite/文件），
  再通过 `MethodChannel` 回传或启动 BGTask 调用 `NetworkClient` 上传 MicroTripServer。
- **省电策略**：`pausesLocationUpdatesAutomatically` 当前 `false`（持续）。如评估耗电，
  可改 `true` 并由业务在关键节点 `startUpdatingLocation()` 续采。

---

## 5. 排错

| 现象 | 处理 |
|------|------|
| 退后台几秒后定位停 | 未勾 Background Modes(Location updates)；或 `allowsBackgroundLocationUpdates` 被 Info.plist 缺 `UIBackgroundModes(location)` 覆盖 |
| 真机跑报能力不匹配 | Xcode Capability 与 Apple 后台 App ID 后台能力未同时开启 |
| 始终授权弹不出 | Info.plist 缺 `NSLocationAlwaysAndWhenInUseUsageDescription` |
| BGTask 不触发 | `BGTaskSchedulerPermittedIdentifiers` 与代码中 `refreshTaskId` 不一致；或系统未到 `earliestBeginDate` |
| 审核被拒 | 后台定位用途说明不清；需在隐私与审核备注充分描述轨迹录制场景 |
