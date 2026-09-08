# 质量工程化指南（P2）

> 适用：MicroTrip（Flutter 客户端）+ MicroTripServer（Node 后端）
> 目标：测试补齐 + CI/CD + 性能 + iOS 后台轨迹，形成可重复的工程质量基线。

---

## 1. 测试策略

### 1.1 服务端（MicroTripServer）—— 已实跑 ✅

技术栈：**Node 内置 `node:test` + `node:sqlite`**，无需第三方测试框架，无需起端口。

- 运行：`npm test`（等价于 `node --experimental-sqlite --test`）。
- 隔离：测试前置通过 `DB_PATH` 环境变量把 SQLite 重定向到 `os.tmpdir()` 临时库，
  并固定 `JWT_SECRET`，不污染真实 `data/microtrip.db`、不写 `.jwt_secret`。
- 范围：进程内直接调用各 controller（mock `req/res/next`），覆盖：
  - `auth`：注册（201/409 重复/400 非法/401 登录错误）、登录、登出。
  - `trajectory`：sync 幂等 upsert、list 分页/摘要字段、detail 完整字段、delete、越权不可见。
  - `scenery`：list 城市注入、detail、detail 404、nearby 距离格式化。
  - `food`：list/detail/shops 城市注入、404。
  - `vision`：未配密钥 → 501 `NOT_CONFIGURED`、标签匹配 scenery/food（stub 腾讯云）、缺图 → 400。
- 现状：**30 个用例全绿**（本沙箱 `node --test` 实测通过）。

> 注意：test 文件里对 `trajectory` 关闭了连接级外键强制（`PRAGMA foreign_keys = OFF`），
> 以便用任意 `user_id` 专注测轨迹逻辑，不依赖真实用户行。

### 1.2 客户端（MicroTrip）—— 已实跑 ✅（16 文件 / 50 用例全绿）

运行：`flutter test` → **50 passed, 0 failed**（截至 2026-09-08，详见 `README.md`「近期质量与体验修复」）。

| 测试文件 | 覆盖点 |
|----------|--------|
| `login_anti_double_tap_test.dart` | 登录/注册/一键体验连点仅提交 1 次（Dio 计数适配器断言 `calls==1`） |
| `login_polish_test.dart` | 注册确认密码一致、密码强度提示渲染 |
| `login_validation_test.dart` | 手机号/密码空值与格式校验分支 |
| `login_rate_limit_test.dart` | 429 限流倒计时锁 |
| `login_agree_hint_test.dart` | 一键体验首次同意提示 |
| `experience_idempotent_test.dart` | 一键体验幂等（重复进入不重复创建演示账号） |
| `trajectory_record_cancel_test.dart` | 录制页「取消」不触发 stop（`_FakeRecNotifier` 记录是否保存） |
| `trajectory_detail_overflow_test.dart` | 渲染树几何遍历判定统计网格 6 瓦片不越界（长内容×字号 1.0/1.25/1.5×屏宽 320/360/375/402 矩阵 + 负面验证） |
| `list_page_back_button_test.dart` | 列表页返回按钮存在且 `router.pop()` 移除页面（独立 GoRouter 验证） |
| `home_refresh_tap_test.dart` | 首页刷新点击 |
| `day_card_center_test.dart` | 10 天预报居中 |
| `http_client_test.dart` | 拦截器 429/403/401 处理 |
| `settings_page_test.dart` | 设置页（签名/同步/通知开关） |
| `overflow_scan_test.dart` | 全量布局溢出扫描（捕获并分类 RenderFlex 越界） |
| `data_source_test.dart` | 模型 `fromJson` 契约 + `SceneryService`/`FoodService` 列表筛选与标签派生 |
| `gpx_service_test.dart` | GPX 导出/回读/合并往返一致 |

- 纯 Dart 单测（`data_source_test` / `gpx_service_test` 中无 Flutter 绑定的部分）覆盖模型契约；
  双源拉取（`DataConfig`/`AuthService` 依赖 `shared_preferences`）走 `flutter test` 集成层。
- 溢出检测正统做法：遍历渲染树几何（`size` vs 子节点 `getTransformTo`），避 `takeException` 漏报；
  详情页 6 瓦片越界真因由 `GridView` 固定 `childAspectRatio` 改为 `LayoutBuilder`+`Wrap` 自适应修复，
  门禁经负面验证（临时去 `Expanded` 该测试 FAIL，恢复后 PASS）。

---

## 2. 性能要点

| 关注点 | 现状 / 做法 |
|--------|-------------|
| 轨迹列表流量 | 服务端 `/trajectory/list` 仅返回摘要（不含 GPS 点），`pageSize ≤ 50` 分页，客户端用 `hasMore` 续拉 |
| 轨迹详情 | `/trajectory/:id` 才返回完整 `pts`，避免列表页拉重数据 |
| 无网体验 | 「模拟数据总开关」开启或请求失败时自动降级本地 mock，页面永白屏 |
| 图片资源 | 列表/详情当前用 emoji 占位（`image` 字段），零网络图片开销；后续换网络图时建议加缓存 |
| 列表渲染 | Riverpod `FutureProvider.family` + `AsyncValue.when`，加载/错误/空态分离；来源 chip 提示数据来源 |
| 接口并发 | 美景/美食/门店均为独立 `family` provider，切换城市/开关 `invalidate` 精准刷新，不全局重建 |

**建议 profiling 路径（Phase 4 接入工具后）**：`flutter run --profile` +
DevTools Performance / Memory 看轨迹录制与长列表滚动；重点关注 GPS 点批量写入与地图渲染。

---

## 3. 静态分析与规范

- 客户端：`analysis_options.yaml` 已启用 `flutter_lints ^6`。本 P2 新增代码已通过
  `dart analyze lib`（`No issues found!`），并主动规避 `avoid_print`（用 `debugPrint`）。
- 服务端：CI 中用 `node --check` 逐一校验 `src/**/*.js` 语法。

---

## 4. CI/CD

### 4.1 客户端 AAB（`.github/workflows/build_aab.yml`）
- 触发：`push` 打 `v*` tag 或手动 `workflow_dispatch`。
- 步骤：setup-java 17 → setup-flutter 3.44 → `flutter pub get` → `flutter analyze`
  → `flutter test` → `flutter build appbundle --release` → 上传 `app-release.aab` 产物（保留 30 天）。
- 说明：未签名 AAB，正式发布需在本地/密钥环境用 `flutter build appbundle` 配合上传密钥，
  或接入 `r0adkll/upload-google-play` 直传 Play Console（需服务账号 JSON）。

### 4.2 服务端（`.github/workflows/ci.yml`）
- 触发：`MicroTripServer/**` 变更或手动。
- 矩阵：Node 18/20/22；步骤：`node --check` 语法校验 + `npm test` 跑接口测试套件。

---

## 5. iOS 后台轨迹（脚手架，需 Mac/Xcode 收尾）

文件：
- `ios/Runner/Info.plist`：已加 `UIBackgroundModes(location/fetch)` 与
  `BGTaskSchedulerPermittedIdentifiers(com.microtrip.backgroundRefresh)`；含
  `NSLocationWhenInUseUsageDescription` / `NSLocationAlwaysAndWhenInUseUsageDescription`。
- `ios/Runner/BackgroundLocationManager.swift`：`CLLocationManager`
  （`allowsBackgroundLocationUpdates = true`）+ `BGTaskScheduler` 注册/续订，
  位置更新通过 `onLocationUpdate` 回调。
- `ios/Runner/AppDelegate.swift`：在 `didInitializeImplicitFlutterEngine` 注册
  `MethodChannel('microtrip/location')`，接收 Dart 的 start/stop/schedule。
- `lib/services/ios_background_location.dart`：Dart 侧桥接（`Platform.isIOS` 守卫，
  Android 安全忽略），提供 `start()`/`stop()`/`scheduleBackgroundRefresh()` 接入点。
- `lib/providers/app_providers.dart` 的 `TrajectoryRecordingNotifier`（**Dart 接入已完成 ✅**）：
  - `start()`：录制开始时并行调用 `IosBackgroundLocation.start()` + `scheduleBackgroundRefresh()`
    （与 Android `BackgroundRecorderService.start()` 并列）。
  - `stop()`：录制结束时并行调用 `IosBackgroundLocation.stop()`。
  - 录制页 `trajectory_record_page.dart` 通过 `trajectoryRecordingProvider.notifier` 调用，
    故「开始录制启后台、结束停后台」已自动生效；非 iOS 平台在桥接内安全忽略。

**待 Mac 完成（原生/Xcode 收尾）**：
1. Xcode → Signing & Capabilities 勾选 Background Modes（Location updates、Background fetch），
   并在开发者后台 App ID 开启对应能力。
2. 确认原生 `BackgroundLocationManager.swift` 在 `didUpdateLocations` 仅做「保活 + 缓存」，
   真实轨迹点仍由 Flutter 侧 `TrajectoryService`（geolocator）采集；如需原生直接落库，
   在 `didUpdateLocations` 批量缓存后通过 `MethodChannel` 回传或本地 SQLite 落地，由同步模块上传。
3. 真机联调：退到后台观察定位是否持续（系统状态栏蓝条/箭头），验证不被系统挂起。
4. 签名、Archive、上传 TestFlight/App Store；HealthKit 等其余能力按需开启。

---

## 6. 下一步（P3 已完成项 + 待收尾）

### 6.1 P3 已完成：真实 Vision API（云端服务代理 + 景点/美食识图）
- 服务端 `POST /vision/recognize`（需 Bearer）代理腾讯云图像分析 `tiia` 的 `DetectLabel`，
  返回标签列表 + 对 `scenery.json`/`food.json` 的匹配推荐（top3）。
- 腾讯云客户端 `src/utils/vision/tencent.js`：纯 `crypto`+`https` 实现 TC3-HMAC-SHA256 签名，无 SDK 依赖。
- 客户端 `PhotoRecognitionService` 改为真实请求（无 mock 伪造）；`photo_recognition_page.dart`
  展示标签 + 可点击的「相关美景/美食」推荐卡片；发现页 AppBar 增加「📷 拍照识物」入口。
- 文档：`docs/API.md` 第 5.4 节 + 6.7 节、README 接口表/目录/环境变量、`.env.example` 补 Vision 变量。
- 验证：`dart analyze lib` 零问题；服务端测试新增 3 个 vision 用例（共 30）。

### 6.2 待收尾 / 待验证清单

> 本沙箱已自动验证：服务端 `npm test` **30/30 全绿**；客户端 `dart analyze lib` **无问题**；
> 轨迹字段命名已于本轮统一（见下方 ✅）。以下项依赖你的本地/云端环境，无法在沙箱完成。

- [x] **轨迹字段命名统一** ✅ 已完成：服务端详情响应与入库入参、客户端 `TrajectoryRecord`
      （`toMap`/`fromMap`）、`docs/API.md`、`README.md`、服务端测试全部统一为长字段名
      `distance` / `duration` / `ascent` / `descent` / `avgSpeed`，消除 list/detail 双套命名，
      客户端解析分支减半。服务端测试 30/30、客户端 `dart analyze` 均绿。
- [ ] **联网跑 `flutter test`** 确认客户端单测全绿（沙箱离线，`flutter` 命令不可用，`dart analyze` 已绿）。
- [ ] 在 GitHub 实际触发两次 CI，验证 AAB 产物与 server 测试（需推送到仓库后由 Actions 运行）。
- [ ] **真实腾讯云联调**：服务端配置 `VISION_SECRET_ID`/`VISION_SECRET_KEY`，用真机拍照验证
      识别与匹配。步骤见 `MicroTripServer/docs/VISION_SETUP.md`；仓库已提供本地一键脚本
      `MicroTripServer/scripts/test_vision.js`（`npm run vision:test -- 照片.jpg --direct` 直连验密钥，
      或 `--phone/--password` 走服务端全链路），沙箱无网络/密钥仅结构验证、未跑通真实调用。
- [ ] iOS 后台轨迹在 Mac 上编译验证 + 真机后台录制测试（需 Xcode / 真机 / 签名）。
