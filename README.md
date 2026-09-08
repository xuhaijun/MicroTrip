# 微旅途 MicroTrip（Flutter 版）

> 旅游伴侣 APP · Flutter 跨端实现（Android / iOS / Windows）
> 由微信小程序版「微旅途」迁移而来，保持一致的功能与视觉风格。

## 已交付功能

### Phase 1 —— 基础体验（已交付）

| 模块 | 功能 | 对应小程序 |
|------|------|-----------|
| 首页 | 城市栏、天气大卡（实时+3日）+ 卡外天气提醒条、今日概览（海拔/步数，点击跳详情页）、附近探索、快捷功能（两行四列 8 项，含海拔信息）、小途助手卡 | pages/index |
| 发现 | 美食/美景推荐列表、AI 智能推荐生成 | pages/discover |
| 行程 | 万年历速览、备忘概览、轨迹入口 | pages/trip |
| 我的 | 用户卡、数据统计、收藏/设置/关于 | pages/profile |
| 城市选择 | 搜索 / GPS 定位 / 热门城市 / 省份分组 / 最近访问 | city 分包 city-list |
| 天气详情 | 实时详情、未来 24 小时、7 天预报、出行建议 | tools 分包 weather |
| 小途 AI | 气泡式聊天、历史持久化（最近 20 条上下文）、清空会话 | travel 分包 suggest |
| 备忘 | 列表、新建/编辑、3 档优先级、提醒时间、滑动删除 | tools 分包 memo/memo-edit |
| 收藏 | 美食/景点收藏管理 | tools 分包 favorites |
| 设置 | 天气 / AI 接口运行时覆盖配置、恢复默认、清除数据 | tools 分包 settings |

### Phase 2 —— 出行工具（已交付）

| 模块 | 功能 | 对应小程序 |
|------|------|-----------|
| GPS 轨迹录制 | 实时地图跟点、开始/暂停/继续/结束、标题命名 | travel 分包 track |
| 停留点检测 | 滑动窗口算法（100m 半径 / 10 分钟阈值）、自动标注停留区域 | travel 分包 track |
| 轨迹统计 | 距离、时长、平均速度、爬升/下降、海拔极值、点数 | travel 分包 track |
| 轨迹列表 | 历史记录卡片、汇总统计（总数/总距离/总时长）、空态引导 | travel 分包 track |
| 轨迹详情 | 全屏地图回放、6 宫格统计、停留点列表、编辑标题/备注 | travel 分包 track |
| 截图分享 | 一键截图轨迹卡片 → 系统分享面板（微信/相册等） | travel 分包 track |
| 拍照识物 | 相机/相册选图、识别结果卡（分类/置信度/描述/养护建议） | tools 分包 recognize |
| 今日步数 | 环形进度、距离/卡路里换算、运动等级徽章、近 7 日走势、点击跳步数详情页（自绘 7 天柱状图） | tools 分包 steps |

> Phase 2 的「拍照识物」与「步数」当前为 Mock 降级实现（离线可跑），
> 接口层已预留真实 API 接入点（Vision API / 微信运动解密），Phase 4 对接后端时直接替换。

### Phase 3 —— 攻略与日历（已交付）

| 模块 | 功能 | 对应小程序 |
|------|------|-----------|
| 美食推荐 | 城市场景化列表、搜索、分类筛选、评分/价格/标签 | city 分包 food 列表 |
| 美食详情 | 图文详情、标签、小贴士、推荐店铺、收藏写入 | city 分包 food 详情 |
| 美景推荐 | 城市场景化列表、搜索、分类筛选、门票/时长信息 | city 分包 scenery 列表 |
| 景点详情 | 开放时间/地址信息面板、周边逛逛推荐、收藏写入 | city 分包 scenery 详情 |
| 一日游攻略 | 5 段式时间轴（上午→晚上）、AI 行程优化、一键复制分享文案 | travel 分包 oneday |
| 万年历 | 6×7 月历、农历小标签、休/班角标、滑动切月、宜忌/干支/冲煞等老黄历、即将到来假期倒计时 | tools 分包 calendar |
| 节假日数据 | 2024-2026 全部法定假日与调休安排（90+ 条）+ 14 个固定节日 | utils/holidays.js |

> Phase 3 农历/宜忌底层使用 **lunar: ^1.7.8**（6tail 官方 Dart 版，与小程序
> `lunar-lib.js` 同源），API 完全兼容；美食/景点数据按当前城市动态场景化，
> 收藏直接写入「我的-收藏」页（`FavoriteType.food / scenery`）。

### Phase 4 —— 后端接入与发布准备（已交付）

| 模块 | 功能 | 对应小程序 |
|------|------|-----------|
| 双模式认证 | 本地演示（crypto 纯 Dart HMAC-SHA256 本地签发 JWT）/ 云端后端（REST）无缝切换 | travel 分包 login |
| 健康步数 | Health Connect / HealthKit 真实步数读取，未授权静默降级 mock | tools 分包 steps |
| 天气推送 | 每日 08:00 本地通知（zonedSchedule + matchDateTimeComponents） | tools 分包 settings |
| 图标 | Android/iOS 多密度图标 + adaptive icon（Pillow 补齐缺失密度） | — |
| 上架清单 | `RELEASE.md` 发布检查清单（权限/图标/隐私/iOS/版本/各渠道） | RELEASE.md |

> Phase 4 详细设计见 `docs/architecture.md` §5.14–§5.17。

### Phase 5 —— 云端同步与后台录制（已交付）

| 模块 | 功能 | 说明 |
|------|------|------|
| 后端服务 MicroTripServer | 新建 Node.js + Express + SQLite 服务：JWT 认证 + 轨迹同步 API | 独立项目 `D:\FlutterProjects\MicroTripServer` |
| 云端同步 | 登录后「手动同步」把本地轨迹上传到 `serverUrl`，无后端时优雅降级 | 设置页按钮 + 状态反馈 |
| 云端历史 | `GET /trajectory/list` 列表 + 详情（可下载到本地） | `cloud_trajectory_page` |
| 后台轨迹录制 | `flutter_background_service` 前台 Service 保活 Android 后台录制（Android 14 `foregroundServiceType=location`） | `background_recorder_service` |
| UI 动效 | 8 处进场 / 交错排列 / 数值滚动动效升级 | `core/animations/anim_effects.dart` |
| Release 签名 | 生成 release keystore + `build.gradle.kts` 签名接入 + 脱糖，产出签名 APK（63MB，V2 签名） | `android/app/build.gradle.kts` |

> ✅ **Release 构建**：项目现已位于 **ASCII 路径** `D:\FlutterProjects\MicroTrip`，`flutter build apk --release` 的 AOT 阶段不会因中文路径乱码失败，**可直接在原目录执行 Release 构建**（历史中文路径坑见 `RELEASE.md` §2.5）。

## 后端技术栈（MicroTripServer）

- **Node.js 22** + **Express 5**（async handler 错误自动传播到错误中间件）
- **SQLite**：Node 22 内置 `node:sqlite`（DatabaseSync，零原生依赖；better-sqlite3 在 Node 22.12 ABI 127 下段错误已规避）
- **认证**：`jsonwebtoken` HS256（30 天有效期，对齐 App 端）+ `bcryptjs` 纯 JS 密码哈希
- **协议**：与 App 端 `TrajectoryRecord.toMap()` 字段对齐，轨迹同步按 `id` 幂等 upsert，`{error:{code,message}}` 统一错误结构
- 启动：`npm start`（内部带 `--experimental-sqlite` flag）

## 技术栈

- **Flutter 3.44 / Dart 3.12**
- 状态管理：flutter_riverpod（Notifier / FamilyNotifier / AsyncNotifier / FutureProvider.family）
- 路由：go_router（StatefulShellRoute.indexedStack 底部 4 Tab 保活）
- 网络：dio（双层缓存：内存 + SharedPreferences 持久化，30 分钟 TTL）
- 存储：shared_preferences（键与小程序 `travel_` 前缀完全一致）
- 定位/轨迹：geolocator（GPS 流订阅）+ flutter_map（天地图瓦片渲染，磁盘缓存离线可用）
- 地图：flutter_map 7.x + latlong2（Haversine 距离计算）+ 天地图 Web 墨卡托双层瓦片（vec_w 底图 + cva_w 注记；CGCS2000≈WGS-84，无需坐标转换；`CachedTileProvider` 磁盘缓存零新依赖）
- 分享：screenshot（控件截图）+ share_plus（系统分享面板）
- 识物：image_picker（相机/相册选图）
- 农历/老黄历：lunar ^1.7.8（6tail 官方 Dart 版，与小程序 lunar-lib.js 同源）

## 快速开始

```powershell
# 建议先设置国内镜像（可写入系统环境变量）
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:Path = "D:\dev\flutter\bin;" + $env:Path

cd D:\FlutterProjects\MicroTrip
flutter pub get
flutter run -d windows        # Windows 调试
flutter devices               # 查看可用设备
flutter run -d <device-id>    # Android / iOS 真机或模拟器
```

> ⚠️ 注意：`flutter analyze` 在含中文的路径下会因 analysis server 的 LSP
> 编码问题崩溃（本项目路径含中文属正常现象），请改用：
> `dart analyze`（或直接使用 IDE 的分析器）。

## API 配置

内置默认配置位于 `lib/core/config/app_config.dart`（与小程序 config.js 同源）：
- 和风天气：专属 API Host + Key（2026 新版每个账号独立 Host）
- AI 大模型：智谱 GLM（OpenAI 兼容格式）
- 腾讯地图：逆地理编码 Key
- 天地图：瓦片源 tk（`AppConfig.tdtKey`，天地图控制台「浏览器端」应用；未配置时瓦片返回 403，地图页底图空白）
- 拍照识物：Vision API 预留（OpenAI 兼容格式，未配置时走 Mock）

也可在 **App 内「我的 → 设置」** 运行时覆盖（保存在本机，优先级高于内置值）。
**未配置 / 失效时全部自动降级 Mock 数据，不影响开发调试。**

## 目录结构

```
lib/
├── main.dart               # 入口（存储初始化 + ProviderScope）
├── core/                   # 基础层：theme / config / http / storage / geo
│                           #   geo/：天地图瓦片缓存 Provider（CachedTileProvider）+ GCJ-02 转换工具（保留备用）
├── models/                 # 数据模型（City / Weather / AiMessage / Memo /
│                           #   Favorite / Trajectory / StepData / RecognitionResult /
│                           #   FoodItem / SceneryItem / OneDayPlan / Calendar*）
├── services/               # 服务层（Weather / Ai / Location / CityData /
│                           #   Trajectory / Step / PhotoRecognition / Repo /
│                           #   Food / Scenery / OneDay / HolidayData / Lunar）
├── providers/              # Riverpod 状态层（含 Phase 2 录制/历史/步数 Notifier）
├── router/                 # go_router 路由表 + 底部导航外壳
├── widgets/                # 共享组件（地图组件 / 通用卡片等）
└── pages/                  # 视图层（home / discover / trip / profile /
                            #   city / ai / trajectory / photo / shared /
                            #   food / scenery / oneday / calendar）
```

完整架构设计见 [`docs/architecture.md`](docs/architecture.md)。

## 后续迭代（Roadmap）

> 状态图例：✅ 已交付　🔜 进行中　📋 规划中

| 阶段 | 状态 | 核心范围 |
|------|------|---------|
| Phase 1–3 | ✅ | 基础体验 / 出行工具 / 攻略与日历 |
| Phase 4 | ✅ | 后端接入（JWT / 健康步数 / 天气推送）、图标、上架清单 |
| Phase 5 | ✅ | 云端同步（MicroTripServer）、后台轨迹录制、UI 动效、Release 签名 |
| Phase 6 | 🔜 | 上架发布与合规（Google Play + 国内渠道 + iOS App Store） |
| Phase 7 | 📋 | 功能增强（真实 API 接入、数据分析、多城市天气） |
| Phase 8 | 📋 | 体验与质量（测试补齐、CI/CD、性能、深色模式 / i18n） |
| Phase 9 | 📋 | 商业化与增长（埋点、会员、运营位） |

### ✅ Phase 4/5 期间已额外落地（原 Roadmap 未同步）

- 隐私政策 / 用户协议页 + **首次启动征询弹框**（不同意即退出，符合国内商店合规）— `pages/profile/privacy_policy_page.dart`、`user_agreement_page.dart`、`pages/shared/splash_page.dart`
- 启动引导页（四屏功能亮点）+ 登录 / 注册门控（`/splash → /guide → /home`）— `pages/shared/guide_page.dart`
- 轨迹**编辑**（标题/备注）、**多选合并**、**导出 GPX**（单条 + 合并，分享面板）— `services/gpx_service.dart`、`pages/trajectory/*`

### 🔜 Phase 6 —— 上架发布与合规（当前重点）

| 目标 | 任务 | 说明 |
|------|------|------|
| Google Play | AAB 构建 + 上架 | `flutter build appbundle --release`；数据安全表单（Data Safety）、测试账号、应用截图 |
| iOS App Store | 归档 + 上架 | macOS 下 `flutter build ios` + Xcode Archive；补 `PrivacyInfo.xcprivacy` 隐私清单、LaunchScreen 品牌定制、TestFlight 内测 |
| 国内渠道 | 华为 / 小米 / OPPO / vivo | 软著 / 电子版权证书、各渠道截图与描述、包名统一 `com.xuhai.micro_trip` |
| 上架素材 | 截图 / 描述 / 隐私政策 URL | 5+ 张截图（首页 / 天气 / 行程 / AI / 我的）、详细描述、隐私政策托管（腾讯文档 / GitHub Pages） |
| 账号合规 | 账号注销入口 | 小米等渠道强制要求；当前仅有退出登录 / 清除数据，需补注销 API + 二次确认流程 |

### 📋 Phase 7 —— 功能增强

| 模块 | 规划 |
|------|------|
| 拍照识物 | 接入真实 Vision API（当前 Mock 降级，接口已预留） |
| 备忘提醒 | 提醒时间接入本地通知调度（当前仅天气推送使用通知） |
| 轨迹分析 | 月度 / 年度统计报表、轨迹热力图、GPX 导入 |
| 多城市天气 | 城市天气管理（添加 / 删除 / 排序）、空气质量与生活指数 |
| AI 行程规划 | 结合天气 + 景点 + 用户偏好生成完整行程（当前一日游为静态模板 + 优化） |
| 云端增强 | 多设备同步、账号体系完善（改密 / 注销）、云端轨迹恢复本地 |

### 📋 Phase 8 —— 体验与质量

| 方向 | 规划 |
|------|------|
| 测试补齐 | 按 `docs/QUALITY.md` 落地客户端单测（模型 fromJson 契约、Service Mock、Widget 冒烟） |
| CI/CD | GitHub Actions：analyze + test + 自动构建 APK / AAB 产物 |
| 性能优化 | 按 `docs/performance_optimization.md` 执行（启动耗时、地图瓦片缓存、列表流畅度） |
| 深色模式 / i18n | 跟随系统深色主题；中英双语（flutter_localizations） |
| 桌面 / Web | 完善 Windows 运行体验，评估 Web 端（天地图瓦片与 geolocator 在 Web 的兼容性） |

### 📋 Phase 9 —— 商业化与增长

| 方向 | 规划 |
|------|------|
| 数据埋点 | 关键页面 PV/UV、功能使用率（自研轻量埋点，无第三方 SDK） |
| 会员体系 | 天气 / AI 高级权益、去广告 |
| 运营位 | 首页 banner、活动页、分享拉新（海报生成） |

---

## 近期质量与体验修复（2026-09-08）

> 围绕「账号安全 + 轨迹录制防误存 + 列表/详情页可访问性与溢出」三类问题，集中完成 **15 项 UX / 质量修复**，并补齐 **16 个客户端测试文件（共 50 个用例，全部通过 `flutter test`）**，质量门禁见 `docs/QUALITY.md` §1.2。

### 账号与安全

| # | 修复 | 关键文件 |
|---|------|----------|
| 1 | 登录 / 注册 / 一键体验按钮**防重复点击**（本地 `_submitting` 同步守卫，失败复位、成功跳走） | `pages/profile/login_page.dart` |
| 2 | 注册新增**确认密码**，提交校验两次一致 | `pages/profile/login_page.dart` |
| 3 | 登录成功后**预填上次手机号**（仅持久化手机号，不存密码） | `services/auth_service.dart`、`pages/profile/login_page.dart` |
| 4 | 密码框实时**强度提示**（弱 / 中 / 强三档） | `pages/profile/login_page.dart` |
| 5 | 详情页与列表页统一**头部返回按钮**（自定义 `GradientHeader`，非 AppBar，需显式返回） | `pages/shared/memo_list_page.dart`、`pages/trajectory/trajectory_page.dart` |

### 轨迹录制与详情

| # | 修复 | 关键文件 |
|---|------|----------|
| 6 | 录制页点「取消」**不再保存**（弹窗取消分支返回 `null` 显式中止 stop，保留录制态） | `pages/trajectory/trajectory_record_page.dart` |
| 7 | 轨迹详情页**统计网格 6 瓦片溢出**修复（`GridView` 固定比例在窄屏/大字下压矮内容 → 改用 `LayoutBuilder` + `Wrap` 自适应高度） | `pages/trajectory/trajectory_detail_page.dart` |

### 编辑与列表体验

| # | 修复 | 关键文件 |
|---|------|----------|
| 8 | 编辑备忘页**保存按钮移入列表**（置于「删除备忘」上方，不再固定底部遮挡） | `pages/shared/memo_edit_page.dart` |
| 9 | 最近轨迹 / 备忘提醒列表页**补充返回按钮** | `pages/trajectory/trajectory_page.dart`、`pages/shared/memo_list_page.dart` |
| 10 | 头部标题 `maxLines:2 + ellipsis`，长标题不再溢出 | `pages/shared/widgets/common_widgets.dart` |

### 早期已交付（本轮一并纳入测试回归）

- 限流 429 倒计时、拦截器 429 / 403 处理、首页刷新、10 天预报居中、一键体验同意提示与幂等、登录注册校验优化（对应 `login_rate_limit_test` / `login_validation_test` / `login_agree_hint_test` / `experience_idempotent_test` / `home_refresh_tap_test` / `day_card_center_test` / `http_client_test` / `settings_page_test` / `overflow_scan_test`）。

### 测试覆盖（16 文件 / 50 用例）

| 测试文件 | 覆盖点 |
|----------|--------|
| `login_anti_double_tap_test.dart` | 连点仅提交 1 次（Dio 计数适配器断言 `calls==1`） |
| `login_polish_test.dart` | 确认密码一致、密码强度提示渲染 |
| `login_validation_test.dart` | 手机号/密码空值与格式校验 |
| `login_rate_limit_test.dart` | 429 倒计时锁 |
| `login_agree_hint_test.dart` | 一键体验同意提示 |
| `experience_idempotent_test.dart` | 一键体验幂等 |
| `trajectory_record_cancel_test.dart` | 取消不触发 stop（_FakeRecNotifier 记录） |
| `trajectory_detail_overflow_test.dart` | 渲染树几何遍历判定 6 瓦片不越界（含长内容×字号×屏宽矩阵 + 负面验证） |
| `list_page_back_button_test.dart` | 列表页返回按钮存在且 `router.pop` 移除页面 |
| `home_refresh_tap_test.dart` | 首页刷新点击 |
| `day_card_center_test.dart` | 10 天预报居中 |
| `http_client_test.dart` | 拦截器 429/403 处理 |
| `settings_page_test.dart` | 设置页 |
| `overflow_scan_test.dart` | 布局溢出扫描 |
| `data_source_test.dart` | 模型 `fromJson` 契约 + 服务筛选 |
| `gpx_service_test.dart` | GPX 导出/回读/合并往返一致 |

> 运行：`flutter test` → **50 passed, 0 failed**；`flutter analyze` → **No issues found!**

## License

MIT
