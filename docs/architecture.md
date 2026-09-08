# 微旅途 Flutter 版 — 架构设计说明书

> 本文档描述从微信小程序版迁移到 Flutter 跨端 APP 的整体架构设计。  
> 对应源项目：`D:\FlutterProjects\微旅途小程序\`（微信小程序版）

---

## 1. 项目背景与目标

「微旅途」是一款旅游伴侣应用，集成天气、城市切换、AI 旅行助手（小途）、  
轨迹记录、万年历、备忘提醒、美食/景点推荐、拍照识物、步数统计等功能。

**Flutter 版目标**：

1. 保持与小程序版一致的功能与视觉风格（科技蓝渐变主题）
2. 一套代码同时支持 Android / iOS / Windows（后续可扩展 Web/桌面）
3. 采用 2026 年 Flutter 社区最佳实践：Riverpod + go_router + dio + feature-first 分层

## 2. 技术选型

| 领域    | 选型                                                                                                   | 版本策略                                      | 选型理由                                                                                                 |
| ----- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| 状态管理  | flutter_riverpod                                                                                     | ^2.x                                      | 编译期安全、天然可测试、无 context 依赖、官方推荐                                                                        |
| 路由    | go_router                                                                                           | ^14.x+                                    | 声明式路由、StatefulShellRoute 实现底部 Tab 保活、深链支持                                                |
| 网络    | dio                                                                                                  | ^5.x                                      | 拦截器体系成熟，便于实现缓存/重试/日志中间层                                                                              |
| 本地存储  | shared_preferences                                                                                   | ^2.x                                      | 与小程序 `wx.setStorageSync` 模型一致，键结构 1:1 迁移                                                             |
| 定位    | geolocator                                                                                           | ^13.x+                                    | 跨平台 GPS/网络定位流订阅，对应小程序 `wx.getLocation`                                                               |
| 地图渲染  | flutter_map + 天地图                                                                                    | ^7.x                                      | 国内瓦片源（CGCS2000≈WGS-84 无需坐标转换）；Web 墨卡托双层瓦片（vec_w 底图 + cva_w 注记），`CachedTileProvider` 磁盘缓存离线可用；需天地图 tk |
| 地理计算  | latlong2                                                                                             | ^0.9.x                                    | Haversine 距离 / 方位角 / 边界计算（LatLngBounds）                                                              |
| 截图分享  | screenshot + share_plus                                                                              | ^3.x / ^10.x                              | 控件级截图 → 系统分享面板，实现轨迹卡片分享                                                                              |
| 选图    | image_picker                                                                                         | ^1.x                                      | 相机拍摄 / 相册选择，对应小程序 `wx.chooseMedia`                                                                   |
| 本地认证  | crypto                                                                                               | ^3.0.6                                    | HMAC-SHA256 本地签发/校验 JWT（纯 Dart，无原生依赖）                                                                |
| 健康数据  | health                                                                                               | ^13.3.1                                   | iOS HealthKit / Android Health Connect 步数读取（API 26+）                                                 |
| 本地通知  | flutter_local_notifications                                                                          | ^22.2.0                                   | 每日 08:00 天气提醒推送（zonedSchedule + matchDateTimeComponents）                                             |
| 时区    | timezone + flutter_timezone                                                                          | ^0.11.x / ^4.1.x                          | 通知定时调度需 TZDateTime + 设备真实时区                                                                          |
| 图标生成  | flutter_launcher_icons                                                                               | ^0.14.4                                   | 一键生成 Android/iOS 多密度图标 + adaptive icon                                                               |
| 数据模型  | 手写 fromJson                                                                                          | —                                         | 避免 build_runner 首次构建门槛；模型量可控                                                                         |
| 序列化缓存 | 内存 LRU + prefs 持久化                                                                                   | —                                         | 对齐小程序 requestWithCache 30 分钟缓存策略                                                                     |

## 3. 分层架构

```
┌───────────────────────────────────────────────┐
│  Presentation（视图层）                        │
│  pages/ 按业务域组织 + widgets/ 共享组件        │
│  仅消费 Provider，不直接调用 Service            │
├───────────────────────────────────────────────┤
│  State（状态层）providers/                     │
│  Riverpod Provider/Notifier，持有 UI 状态，     │
│  调用 Service 完成业务                          │
├───────────────────────────────────────────────┤
│  Domain（模型层）models/                       │
│  纯数据类 + fromJson/toJson，无任何依赖         │
├───────────────────────────────────────────────┤
│  Data/Services（服务层）services/              │
│  Weather / Ai / Location / Trajectory / Step  │
│  / PhotoRecognition / Memo / Favorite ...     │
│  依赖 core 层的 http 与 storage                │
├───────────────────────────────────────────────┤
│  Core（基础层）core/                           │
│  theme 主题 / config 配置中心 / http 网络封装   │
│  / storage 存储服务 / constants 常量            │
└───────────────────────────────────────────────┘
```

依赖方向自上而下单向：视图 → 状态 → 服务 → 基础层。

## 4. 目录结构

```
lib/
├── main.dart                    # 入口：ProviderScope + MaterialApp.router
├── app.dart                     # App Widget（主题、路由装配）
├── core/
│   ├── theme/app_theme.dart     # 设计令牌（颜色/圆角/阴影，迁移自 app.wxss CSS 变量）
│   ├── config/app_config.dart   # 配置中心（QWeather/AI/腾讯地图/天地图 tk/Vision，支持用户覆盖）
│   ├── http/http_client.dart    # dio 封装 + 请求缓存（对齐 requestWithCache）
│   └── storage/app_storage.dart # 存储服务（travel_ 前缀键，对齐小程序 storage.js）
│   ├── geo/                     # 地理相关：天地图瓦片磁盘缓存（cached_tile_provider.dart）+ GCJ-02 转换（gcj02.dart，保留备用）
│   └── animations/anim_effects.dart # 动效组件库（进场/交错/数值滚动）[P5]
├── models/                      # CityInfo / WeatherNow / WeatherDaily / AiMessage /
│                                # MemoItem / FavoriteItem / TrajectoryPoint /
│                                # StopPoint / TrajectoryRecord / StepData /
│                                # UserProfile / RecognitionResult / FoodItem / FoodShop /
│                                # CloudTrajectory（云端轨迹摘要，MicroTripServer list 响应）[P5] /
│                                # SceneryItem / NearbyScenery / OneDayPlanItem /
│                                # HolidayInfo / CalendarDayInfo / LunarDayInfo
├── services/
│   ├── weather_service.dart     # 和风天气（now/7d/24h/geo lookup，mock 降级）
│   ├── ai_service.dart          # OpenAI 兼容对话（mock 降级）
│   ├── location_service.dart    # geolocator 定位 + 腾讯逆地理编码
│   ├── auth_service.dart        # JWT 登录体系（本地签发 HS256 / 云端 REST 双模式）[P4]
│   ├── health_service.dart      # HealthKit/Health Connect 步数读取（授权 + 静默失败）[P4]
│   ├── weather_push_service.dart # 每日天气本地通知（zonedSchedule 08:00）[P4]
│   ├── sync_service.dart        # 云端轨迹同步（POST /trajectory/sync，无后端优雅降级）[P5]
│   └── background_recorder_service.dart # 后台轨迹录制前台 Service 封装 [P5]
│   ├── city_data.dart           # 热门城市/按省分组静态数据
│   ├── trajectory_service.dart  # GPS 录制引擎（流订阅/停留点检测/统计）
│   ├── trajectory_repository.dart # 轨迹持久化（travel_trajectories）
│   ├── step_service.dart        # 步数服务（今日/近 7 日，mock 降级）
│   ├── photo_recognition_service.dart # 拍照识物（mock 池 + Vision API 预留）
│   ├── memo_repository.dart     # 备忘 CRUD
│   ├── favorite_repository.dart # 收藏 CRUD
│   ├── food_service.dart        # 美食数据（10 种城市场景化 + 模拟店铺 + 筛选）[P3]
│   ├── scenery_service.dart     # 景点数据（10 个城市场景化 + 周边推荐 + 筛选）[P3]
│   ├── oneday_service.dart      # 一日游 5 段时间轴 + AI 优化 [P3]
│   ├── holiday_data.dart        # 2024-2026 节假日/调休/固定节日数据 [P3]
│   └── lunar_service.dart       # 农历/老黄历封装（lunar 包 + 出行建议）[P3]
├── providers/                   # Riverpod 状态层
│   ├── app_providers.dart       # 城市/天气/AI/备忘/轨迹/步数/收藏/设置
│   └── auth_provider.dart       # 登录态（user / loading / error）[P4]
├── widgets/                     # 跨页共享组件
│   └── map/trajectory_map_widget.dart  # flutter_map 封装（图层/缩放/边界适配）
├── router/app_router.dart       # go_router 路由表 + StatefulShellRoute
└── pages/                       # 按业务域组织（对应小程序主包+分包）
    ├── home/                    # 首页（对应 pages/index，含海拔/步数概览卡 + 快捷宫格；含 altitude_detail_page / step_detail_page 详情页）
    ├── discover/                # 发现（对应 pages/discover）
    ├── trip/                    # 行程（对应 pages/trip + tools/calendar、memo）
    ├── profile/                 # 我的（对应 pages/profile + settings/about；P4 新增 login_page）
    ├── city/                    # 城市选择（对应 city 分包 city-list）
    ├── ai/                      # 小途 AI 助手（对应 travel 分包 suggest）
    ├── trajectory/              # 轨迹（对应 travel 分包 track）
    │   ├── trajectory_page.dart          # 历史列表 + 汇总卡
    │   ├── trajectory_record_page.dart   # 实时录制（地图 + 统计卡片）
    │   └── trajectory_detail_page.dart   # 详情（地图回放 + 停留点 + 截图分享）
    │   └── cloud_trajectory_page.dart     # 云端历史列表（GET /trajectory/list + 详情下载）[P5]
    ├── photo/                   # 拍照识物（对应 tools 分包 recognize）
    │   └── photo_recognition_page.dart
    ├── food/                    # 美食（对应 city 分包 food）[P3]
    │   ├── food_list_page.dart          # 列表：搜索 + 分类筛选（embedded 供发现页 Tab 复用）
    │   └── food_detail_page.dart        # 详情：标签/小贴士/推荐店铺/收藏
    ├── scenery/                 # 景点（对应 city 分包 scenery）[P3]
    │   ├── scenery_list_page.dart       # 列表：搜索 + 分类筛选（embedded 供发现页 Tab 复用）
    │   └── scenery_detail_page.dart     # 详情：信息面板/周边逛逛/收藏
    ├── oneday/                  # 一日游（对应 travel 分包 oneday）[P3]
    │   └── oneday_page.dart             # 5 段时间轴 + AI 优化 + 分享文案
    ├── calendar/                # 万年历（对应 tools 分包 calendar）[P3]
    │   └── calendar_page.dart           # 6×7 月历 + 老黄历详情 + 假期倒计时
    └── shared/                  # 天气详情、备忘编辑、收藏、设置等
        └── widgets/             # weather_card / empty_state / 渐变卡片等共享组件
```

## 5. 关键设计决策

### 5.1 配置中心与用户覆盖

`core/config/app_config.dart` 内置默认 API 配置（与小程序 config.js 一致），  
`settings_provider` 允许在「设置」页运行时覆盖（存 prefs），读取顺序：  
**用户覆盖 > 内置默认**。与小程序 getWeatherConfig()/getAIConfig() 模式一致。

### 5.2 API 失败自动降级 Mock

天气/AI/识物/步数服务在「未配置 Key / 网络失败 / Host 失效」时自动返回模拟数据并标记  
`isMock=true`，保证 UI 永远有内容 —— 完整迁移小程序的降级策略，并扩展到 Phase 2 模块。

### 5.3 路由与底部导航

使用 go_router `StatefulShellRoute.indexedStack` 实现底部 4 Tab  
（首页/发现/行程/我的），各 Tab 状态独立保活（对应小程序 tabBar + custom-tab-bar）。  
Phase 2 新增 3 条全屏路由（无底部栏）：  
`/trajectory-record`、`/trajectory-detail/:id`、`/photo-recognition`。  
2026-08 迭代新增 `/altitude-detail`、`/step-detail`（首页海拔/步数详情页）。

### 5.4 存储键兼容

存储键与小程序完全一致（`travel_currentCity`、`travel_memoList`、`travel_trajectories`  
等），未来若做双向数据迁移（小程序 → APP 导入）可直接复用。

### 5.5 主题令牌

颜色/圆角/阴影全部收敛到 `app_theme.dart` 的 `AppColors/AppRadius/AppShadows`  
常量，等价于小程序 app.wxss 的 CSS 变量体系：  
主色 `#0077B6` → 渐变 `#00B4D8`，强调色 `#FF9F43`，背景 `#F7F8FA`。

### 5.6 GPS 轨迹录制引擎（Phase 2）

`TrajectoryService` 为单例录制引擎，与 UI 解耦：

- **定位流**：`Geolocator.getPositionStream`（距离过滤 5m），订阅后持续累积点位
- **状态机**：`idle → recording ⇄ paused → stopped`，暂停期间不采集、不计算
- **实时回调**：`onStatsUpdate` 将 `TrajectoryStats`（距离/时长/速度/海拔/点数）  
  推送给 Riverpod Notifier，UI 每帧消费
- **距离计算**：Haversine 逐点累加（`latlong2`），剔除精度劣化点（accuracy > 50m 丢弃）

### 5.7 停留点检测算法（Phase 2）

滑动窗口实现，无需额外依赖：

1. **候选窗口**：以当前点为圆心、`stopRadius=100m` 为半径收集窗口内全部点位
2. **时长判定**：窗口首尾时间差 ≥ `stopMinDuration=10min` 记为停留
3. **聚合输出**：窗口中心 = 停留点坐标，时长 = 到达/离开时间差，  
   相邻窗口合并去重（间隔 < 1min 视为同一停留）
4. **精度兜底**：窗口内平均 accuracy > 80m 时降低判定置信度（标记，不阻断）

### 5.8 截图分享链路（Phase 2）

`ScreenshotController` 包裹轨迹卡片 → `captureFromWidget` 截取 PNG →  
写入 `path_provider` 临时目录 → `Share.shareXFiles` 调起系统分享面板  
（微信 / 相册 / 保存到文件），分享完成后清理临时文件。

### 5.9 地图组件封装（Phase 2）

`TrajectoryMapWidget` 统一封装 flutter_map 7.x：

- **瓦片源（2026-08 迭代）**：天地图 Web 墨卡托双层瓦片 —— `vec_w` 矢量底图 + `cva_w` 矢量注记（路名/地名透明底叠加），URL 模板见 `app_config.dart`（`tdtVecUrl` / `tdtCvaUrl`，子域 0-7）。天地图使用 CGCS2000 坐标系，与本 App 的 WGS-84 坐标基本重合（<1m），**无需 GCJ-02 转换**。
- **瓦片缓存**：`CachedTileProvider`（`core/geo/cached_tile_provider.dart`）复刻 `NetworkTileProvider` 逻辑 + 磁盘读写分支（`path_provider` 缓存目录），瓦片命中缓存直接解码，离线/弱网也能显示底图；零新依赖（`http` 显式声明）。
- **图层**：TileLayer(天地图双层) + PolylineLayer(轨迹线) + MarkerLayer(起/终点/停留点)
- **交互**：`interactive` 参数控制 —— 录制中非交互（AbsorbPointer 包裹），  
  详情页可拖动/缩放
- **边界适配**：`CameraFit.bounds` 自动缩放到轨迹包围盒（padding 64px），  
  单点轨迹退化为 zoom 15 居中显示

### 5.10 农历库选型（Phase 3）

小程序 `lunar-lib.js`（8538 行）手动移植成本高；pub.dev 上有 **6tail 官方 Dart 版  
`lunar: ^1.7.8`**（verified publisher），API 与 JS 版同源，直接采用：

- `Lunar.fromDate` / `getMonthInChinese` / `getDayInChinese` / `getYearInGanZhi`
- `getDayYi` / `getDayJi` / `getJieQi` / `getDayChongShengXiao` / `getDayNaYin`
- `getPengZuGan/Zhi` / `getXiu` / `getXiuLuck` / `getZhiXing` / `getYearShengXiao`
- `Solar.fromDate().getXingZuo()`（星座）

空值语义（实证验证）：非节气日 `getJieQi()` 返回空串、`getFestivals()` /  
`getOtherFestivals()` 返回空列表，UI 无需判空防御。

### 5.11 城市场景化数据（Phase 3）

`FoodService` / `SceneryService` 为纯静态类，城市名作为参数注入：

- **名称场景化**：数据中 `{city}` 占位符 + 运行时 `replaceAll` 注入城市名  
  （const 列表无法拼接运行时字符串），如「成都历史博物馆」
- **坐标场景化**：门店推荐由 `FoodService.fetchShops(city)` 提供，依据「模拟数据总开关」  
  走服务端 `/food/shops` 或本地 `_mockShops` 兜底（自动降级）；服务端用 `{city}` 注入城市名，  
  本地兜底基于城市中心坐标 ±偏移生成 3 家示例店铺，服务层不耦合全局状态
- **周边推荐**：`nearby()` 排除当前景点取前 4，同样用占位符注入城市名

### 5.12 发现页 Tab 复用真实列表（Phase 3）

`FoodListPage` / `SceneryListPage` 提供 `embedded` 参数：

- `embedded=false`（默认）：独立页面，自带 Scaffold + AppBar（路由直达）
- `embedded=true`：只渲染内容（搜索/标签/列表），嵌入发现页 TabBarView

同一组件双模式复用，避免发现页与独立列表页双份代码漂移。

### 5.13 老黄历旅游向提示（Phase 3）

`LunarService` 在宜/忌文本中做关键词匹配（出行/旅游/远行/移徙/出游/游猎），  
派生 `travelTip`（宜出行 / 忌远行）与 `suggestion` 文案，与小程序  
「黄历宜出行」提示逻辑对齐。

### 5.14 双模式认证体系（Phase 4）

`AuthService` 支持「本地演示」与「云端后端」无缝切换：

- **本地模式（默认）**：注册/登录数据存 `travel_localAccounts`，`crypto` 包纯 Dart 实现 `Hmac(sha256)` 本地签发 JWT（HS256），30 天有效期；HMAC 密钥首次生成后持久化到 `travel_jwtSecret`，保证重启后 token 仍可校验。
- **云端模式**：设置页配置 `serverUrl` 后，登录/注册走 `POST {url}/auth/login|register|logout`，响应 `{token, user}` 自动解析并建立会话。
- **统一对外**：`tokenProvider` 注入 `HttpClient` 拦截器，`needAuth: true` 请求自动附加 `Authorization: Bearer <token>`；任意 401 回调统一清会话并跳转 `/login`。

### 5.15 系统健康数据读取（Phase 4）

`HealthService` 封装 `health: ^13.3.1` 新 singleton API（`Health()` + `configure()`）：

- **权限链**：`hasPermission`（bool? 归一化为 false）→ `requestAuthorization`（显式按钮触发）→ `syncTodaySteps` / `syncStepsForDate`（已授权时读取，未授权静默返回 null）。
- **数据源优先级**：健康平台真实数据 > 本地缓存 > mock 降级。`getTotalStepsInInterval` 汇总接口优先，`getHealthDataFromTypes` 逐条累加兜底（`startTime`/`endTime` 参数，value 转型 `NumericHealthValue.numericValue`）。
- **平台配置**：Android minSdk=26 + `health.READ_STEPS` + Health Connect 应用探测；iOS `NSHealthShareUsageDescription` 声明读取用途。

### 5.16 本地天气通知（Phase 4）

`WeatherPushService` 基于 `flutter_local_notifications: ^22.3.0`：

- **初始化**：`main.dart` 中以 `unawaited` 异步初始化（不阻塞首帧），内部完成时区设置（`flutter_timezone` 获取设备时区 → `tz.setLocalLocation`）、插件初始化、Android 13+ 通知权限申请。
- **每日调度**：`zonedSchedule(id=1001, scheduledDate=今日/明日 08:00, matchDateTimeComponents=DateTimeComponents.time, androidScheduleMode=inexactAllowWhileIdle)` 实现每天同一时刻重复，无需精确闹钟权限。
- **内容刷新**：每次 App 启动或开关开启时拉取 `WeatherService.getNowWeather` + `getForecast` 组装最新文案，覆盖旧调度（同一 ID）。设置页 `SwitchListTile` 即时生效。

### 5.17 图标生成策略（Phase 4）

`flutter_launcher_icons: ^0.14.4` 因 Windows 实时扫描锁定刚生成的 PNG，多次运行失败。最终采用混合策略：

- **Android**：工具成功生成 `drawable-*/ic_launcher_foreground.png`（adaptive foreground）与大部分 `mipmap-*/ic_launcher.png`；缺失的 `mipmap-xxxhdpi` 与 `mipmap-anydpi-v26/ic_launcher.xml` 由 Python/Pillow 脚本补齐。
- **iOS**：15 个独立尺寸全部通过 Pillow 生成（品牌蓝 `#4FC3F7` 背景 + logo 居中），并去除 alpha（`convert('RGB')`），满足 App Store 透明图标限制。

### 5.18 后端服务 MicroTripServer（Phase 5）

独立后端项目 `D:\FlutterProjects\MicroTripServer`，技术栈 **Node.js 22 + Express 5 + 内置 `node:sqlite`**：

- **SQLite 选型**：采用 Node 22 内置 `node:sqlite`（`DatabaseSync`，API 与 better-sqlite3 一致、零原生依赖），规避 better-sqlite3 13.x 在 Node 22.12（ABI 127）下的段错误；启动命令 `npm start` 内部带 `--experimental-sqlite` flag。
- **JWT 协议对齐**：`jsonwebtoken` HS256，payload `{sub,name,phone,iat,exp}`，30 天有效期，与 App 端 `AuthService` 一致；`bcryptjs` 纯 JS 密码哈希（cost 10）；`requireAuth` 中间件解析 `Authorization: Bearer <token>`，失败抛 401；JWT 密钥首次启动随机生成并持久化到 `.jwt_secret`，保证重启后 token 可校验。
- **轨迹同步协议**：与 App 端 `TrajectoryRecord.toMap()` 字段逐一对齐（`id/start/end/pts/dist/dur/stops/maxAlt/minAlt/asc/desc/avgSpd/title/note/city`，pts 用 `{lat,lng,ts,alt,spd,acc,hdg}`）；`POST /trajectory/sync` 按 `id` 幂等 upsert（`ON CONFLICT(id) DO UPDATE`）；列表接口不含 GPS 点省流量；统一错误结构 `{error:{code,message}}`（唯一约束转 409，500 级隐藏内部信息）。

### 5.19 云端同步与历史（Phase 5）

- **SyncService**：组装 `{trajectory: record.toMap()}` 经 `POST {serverUrl}/trajectory/sync` 上传；`needAuth:true`；无 `serverUrl`/未登录时抛出可识别异常，调用方优雅降级（本地数据不受影响）。
- **云端历史列表**：设置页「数据同步」区块含「手动同步」按钮 + 同步状态反馈，并入口到 `CloudTrajectoryPage`（`GET /trajectory/list` 摘要 + `GET /trajectory/:id` 详情，支持下载到本地）。
- **轨迹详情复用**：`TrajectoryDetailPage` 支持 `externalRecord` 直传渲染（云端记录无需经本地 Provider），并区分「云端模式」删除（调 `DELETE /trajectory/:id`）。

### 5.20 后台轨迹录制（Phase 5）

`BackgroundRecorderService` 封装 `flutter_background_service: ^5.1.0`（Android 端解析 6.3.1）：

- **Android 保活**：`AndroidConfiguration(isForegroundMode: true)` + `foregroundServiceTypes: [location]`（满足 Android 14+ location 类型强制声明）+ 通知渠道 `trajectory_recording` + 常驻通知图标 `ic_bg_service_small`（白色定位针，Python/Pillow 生成 5 密度）。UI 与 Service 分属不同 isolate，经 `invoke('stop')` + `service.on('stop')` + `stopSelf()` 通信；后台 isolate 需 `DartPluginRegistrant.ensureInitialized()`。
- **iOS 限制**：iOS 不支持长时后台 Dart，依赖系统后台定位投递（`UIBackgroundModes: location` + `NSLocationAlwaysAndWhenInUseUsageDescription`），不使用该插件的前台 Service。
- **录制链路**：`TrajectoryRecordingNotifier.start()` 成功后 `unawaited(BackgroundRecorderService.start())`；`stop()` 先停后台 Service 再停 GPS，保证前台服务与 GPS 同时正确关闭。

### 5.21 UI 动效升级（Phase 5）

新增 `core/animations/anim_effects.dart` 动效组件库，在 8 处植入：

- **首页**：天气卡进场淡入上移、快捷入口交错排列（StaggeredList） + 按压缩放、AI 卡延迟进场。
- **我的页**：用户卡进场、统计数字滚动（`AnimatedCountingText`）。
- **轨迹录制页**：实时距离/采样点数值滚动（`_StatCard` 带 `animateTo`）。
- **轨迹历史页**：列表卡片交错滑入 + 汇总统计数字滚动。

全部基于 `AnimationController` + `CurvedAnimation`（`easeOutCubic`），尊重 `prefers-reduced-motion` 可后续扩展。

### 5.22 Release 签名构建（Phase 5）

- **签名配置**：`android/app/keystore/release.keystore`（RSA 2048 / 有效期 10000 天）+  
  `key.properties`（gitignored）；`build.gradle.kts` 的 `signingConfigs.release` 经手动解析 `key=value`（规避该脚本作用域内 `java.util` 被 AGP 隐式符号遮蔽导致 `Unresolved reference 'util'`），release 构建使用 `signingConfigs.getByName("release")`。
- **核心库脱糖**：`flutter_local_notifications` 依赖 Java 8+ API，`compileOptions.isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs")` 已启用，否则 `checkReleaseAarMetadata` 失败。
- **路径编码（已规避）**：项目现位于 ASCII 路径 `D:\FlutterProjects\MicroTrip`，`flutter build apk --release` 的 AOT 阶段不会因中文路径乱码失败，可直接原目录构建；历史中文路径坑见 `RELEASE.md` §2.5。

### 5.23 地图瓦片源切换与磁盘缓存（2026-08 迭代）

**背景**：原 OSM（OpenStreetMap）海外瓦片源在国内加载慢、易失败，弱网/离线体验差，需换国内源。

**选型过程**（两轮决策）：

1. **高德瓦片（初选，后弃）**：高德/腾讯瓦片是 **GCJ-02（火星坐标）**，而 App 坐标（GPS / POI / 城市 / 轨迹）为 WGS-84。接入时需在轨迹点、POI、相机中心、边界等 6 处做 `wgs84ToGcj02` 转换，代码侵入大、且转换后仍存在亚米级误差风险。
2. **天地图（最终选定）**：天地图使用 **CGCS2000 坐标系**，与 WGS-84 基本重合（差异 <1m），**无需任何坐标转换** —— 撤销全部高德转换代码后直接显示。

**关键实现**：

- **双层瓦片**：`vec_w`（矢量底图）+ `cva_w`（矢量注记，路名/地名，透明底）叠加，`tdtSubdomains = 0..7` 分散请求。
- **磁盘缓存**：`CachedTileProvider` 零新依赖实现 —— 复刻 `NetworkTileProvider` 的 `_load` 逻辑，增加磁盘读/写分支（`ImmutableBuffer.fromUint8List` 返回 `Future`，需 `await` 后交给 `decode`）；缓存目录经 `path_provider` 获取，命中即解码，离线/弱网仍显示底图。
- **tk 前置**：天地图瓦片 URL 必须带 `tk`（token），否则 403；`AppConfig.tdtKey` 目前为占位符，上线前必须替换为真实 tk（天地图控制台「浏览器端」应用），且瓦片 URL 编译期拼入，替换后需重新构建。
- **应用范围**：`TrajectoryMapWidget`（轨迹录制/回放）与 `NearbyMapPage`（附近探索）统一使用天地图双层瓦片 + 磁盘缓存。

### 5.24 首页概览卡与详情页（2026-08 迭代）

- **天气提醒条幅移出天气卡**：原内嵌白字半透明条幅在渐变天气卡内显臃肿 → 独立为卡外横滑芯片条 `_buildAdviceBanner`（浅主色底 + 主色文字），置于天气卡下方。
- **快捷功能区**：两行四列满 8 项（美食/美景/录制轨迹/拍照识物/一日游/万年历/备忘提醒/海拔信息），标题下间距 6、卡片底部 padding 14、行距 14 / 列距 8，`childAspectRatio 0.87` 防窄屏溢出。
- **海拔/步数卡片点击跳详情页**：`/altitude-detail`（`altitude_detail_page.dart`：GradientHeader + 海拔大卡 + GPS 说明 + 下拉刷新）与 `/step-detail`（`step_detail_page.dart`：步数/距离/热量/等级大卡 + 三项明细 + 纯 Flutter 自绘 7 天柱状图）。
- **海拔刷新修复**：`altitudeProvider` 升级为 `AsyncNotifierProvider`，拆「缓存优先（`build`，秒开）」与「强制 GPS 刷新（`refresh()`）」双策略；刷新按钮带 loading 转圈反馈。**踩坑沉淀**：外部"等待 AsyncNotifier 完成"无公开 API（`AsyncNotifier.future` 是 `@visibleForTesting` protected 成员，`AsyncValue` 无 `future` getter），正确姿势是 `ref.watch` 渲染（UI）或 `ref.listenManual(provider, cb, fireImmediately: true)`（本地状态）—— 详见 `D:\Android开发\Flutter-Riverpod实战指南.html` 第 14 章。

## 6. 分期实施计划

| 阶段      | 范围                                                              | 状态    |
| ------- | --------------------------------------------------------------- | ----- |
| Phase 1 | 骨架 + 4 Tab + 天气 + 城市选择 + AI 助手 + 备忘 + 收藏 + 设置 + 我的              | ✅ 已交付 |
| Phase 2 | 轨迹记录（GPS/停留点/截图分享）、全屏地图、拍照识物、步数                                 | ✅ 已交付 |
| Phase 3 | 一日游攻略、美食/景点详情页 + 收藏写入、万年历农历/宜忌/节假日                              | ✅ 已交付 |
| Phase 4 | 后端接入（JWT 登录、健康步数、天气推送）、图标生成、上架清单                                | ✅ 已交付 |
| Phase 5 | 云端同步（MicroTripServer + 手动同步 + 云端历史）、后台轨迹录制、UI 动效升级、Release 签名构建 | ✅ 已交付 |

## 7. 调试与运行

```powershell
$env:Path = "D:\dev\flutter\bin;" + $env:Path
# 国内镜像（建议写入系统环境变量）
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"

cd D:\FlutterProjects\MicroTrip
flutter pub get
dart analyze                  # 静态检查
flutter run -d windows        # Windows 调试
flutter run -d <android-id>   # Android 真机/模拟器
flutter build apk --debug     # Android 调试包
```

> **Release 构建**：项目位于 ASCII 路径 `D:\FlutterProjects\MicroTrip`，可直接 `flutter build apk --release`；  
> 历史中文路径坑见 `RELEASE.md` §2.5。

### MicroTripServer 启动与联调

```powershell
cd D:\FlutterProjects\MicroTripServer
npm install --cache ".\.npm-cache"   # 若全局 npm 缓存被实时扫描锁，用项目本地缓存
npm start                            # 内部带 --experimental-sqlite，监听 :3000
curl http://localhost:3000/health    # 健康检查
```

> 无后端时 App 端所有云端功能自动降级（本地数据不受影响），可独立开发调试。

> **GPS 调试提示**：Windows 桌面端无 GPS 数据，轨迹录制请使用 Android  
> 真机；模拟器可用 `geo fix <lng> <lat>` 命令注入伪坐标（Android Emulator）。
