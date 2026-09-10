# Changelog

本项目所有重要变更均记录于此文件。格式参考 [Keep a Changelog](https://keepachangelog.com/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased] — 2026-09-08 质量与体验修复

> 集中完成 15 项 UX / 质量修复，并补齐 16 个客户端测试文件（共 50 个用例，`flutter test` 全绿）。
> 静态检查 `flutter analyze` → No issues found!

### Added（新增）

- 客户端测试套件：16 个测试文件 / 50 个用例，覆盖账号安全、轨迹录制、详情溢出、列表返回等核心路径。
- `docs/QUALITY.md` §1.2 客户端测试清单（标注已实跑全绿）。

### Changed（优化）

- **账号与安全**
  - 登录 / 注册 / 一键体验按钮防重复点击（本地 `_submitting` 同步守卫）。
  - 注册新增「确认密码」校验。
  - 登录成功后预填上次手机号（仅持久化手机号，不存密码）。
  - 密码框实时强度提示（弱 / 中 / 强三档）。
- **轨迹录制与详情**
  - 录制页点「取消」不再保存（弹窗取消分支显式中止 stop，保留录制态）。
  - 轨迹详情页统计网格 6 瓦片溢出修复：`GridView` 固定比例 → `LayoutBuilder` + `Wrap` 自适应高度。
- **编辑与列表体验**
  - 编辑备忘页保存按钮移入列表（置于「删除备忘」上方，不再固定底部遮挡）。
  - 最近轨迹 / 备忘提醒列表页补充返回按钮（自定义 `GradientHeader` 需显式返回）。
  - 头部标题 `maxLines:2 + ellipsis`，长标题不溢出。

### Fixed（修复）

- 早期已交付项一并纳入测试回归：限流 429 倒计时、拦截器 429/403、首页刷新、10 天预报居中、
  一键体验同意提示与幂等、登录注册校验优化。

### 涉及关键文件

| 文件 | 改动 |
|------|------|
| `lib/pages/profile/login_page.dart` | 防重复点击、确认密码、预填手机号、密码强度 |
| `lib/services/auth_service.dart` | `kLastPhone` / `saveLastPhone` / `lastPhone`（仅存手机号） |
| `lib/pages/trajectory/trajectory_record_page.dart` | 取消保存中止 stop |
| `lib/pages/trajectory/trajectory_detail_page.dart` | 统计网格 `Wrap` 自适应 |
| `lib/pages/shared/memo_edit_page.dart` | 保存按钮移入列表 |
| `lib/pages/shared/memo_list_page.dart` | 列表页返回按钮 |
| `lib/pages/trajectory/trajectory_page.dart` | 列表页返回按钮 |
| `lib/pages/shared/widgets/common_widgets.dart` | 头部标题省略号 |
| `test/*.dart`（16 文件） | 新增/补齐测试，共 50 用例 |

---

## [Unreleased] — 2026-09-10 界面美化 / 多渠道打包 / 上架合规

> 全量 UI 审计（模拟器 + 真机截图）→ P0 修复 → 首屏快速操作网格 emoji 统一替换为 Material 线性图标；
> 产出 5 个渠道包（华为/小米/OPPO/vivo APK + Google Play AAB）；补齐账号注销入口等上架合规项。
> 静态检查 `flutter analyze` → No issues；`flutter test` 50 用例全绿。

### Added（新增）
- **多渠道打包**：`scripts/build_channels.sh`（Bash 版，规避 PowerShell 下 `flutter.bat` 缺 `ProgramFiles` 环境变量的坑，
  用 `env` 注入）。`--dart-define=CHANNEL=<渠道>` 编译期注入，产物输出 `build/channels/`：
  `microtrip-3.0.0-{huawei,xiaomi,oppo,vivo}.apk` 与 `microtrip-3.0.0-googleplay.aab`。
- **上架合规**：设置页新增「注销账号」入口（两步确认 + 后端 `DELETE /api/v1/auth/account` + 清本地/预填）。
- **隐私政策托管版**：`privacy_policy.html`（根目录，与应用内《隐私政策》同源，可发布到 Gitee Pages 满足渠道后台 URL 要求）。
- **发布指南**：`docs/RELEASE_CHANNELS.md`（各商店提交流程 + 物料清单 + 隐私 URL 托管）；`docs/IOS_RELEASE_CHECKLIST.md`（Mac 归档步骤）。
- **iOS 隐私清单**：`ios/Runner/PrivacyInfo.xcprivacy`（Apple 2024-05 起强制）。

### Changed（优化 / 美化）
- 启动页、关于页版本号硬编码 `v1.0.0` → 统一读 `AppConfig.appVersion`（v3.0.0），避免与 pubspec 漂移。
- 发现页 AI 生成失败：原始异常文本 → 友好提示「小途暂时开小差了，请稍后重试～」。
- 首页「当前海拔」：定位中卡死 → 加 8s 超时回退为「—」（并显示「定位中…」加载态，避免长期占位）。
- **图标体系统一（emoji → Material 线性图标）**，覆盖全部界面图标位：
  - 首页：快捷操作网格 8 项、天气卡湿度/风（💧🌬️ → 水滴/风图标）；
  - 天气：首页大卡、详情实时大卡、24 小时预报、10 天预报、出行建议 chip
    （新增 UI 层映射 `lib/core/ui/weather_icons.dart`——模型层 `WeatherUtils.iconOf` 保持纯 Dart
    返回 emoji 以不破坏纯 Dart 测试，界面统一走 `weatherIconOf` / `adviceIconOf`）；
  - 发现页：分类封面、AI 标题、快捷 Chip（🍜🏞️🤖）；收藏页分类图标；
  - 拍照识物：相关推荐分区标题（🏞🍜）；轨迹页空态（🚀）；
  - 万年历/美食详情提示条（💡）；一日游 AI 标题（🤖）；引导页 4 屏插画（🗺️📍🤖☁️）。
  - 刻意保留的内容型 emoji：微信分享文案、节日名（🎉💝）、天气穿衣建议原文（模型数据）。

### 涉及关键文件

| 文件 | 改动 |
|------|------|
| `lib/core/ui/weather_icons.dart` | **新增** UI 层天气/建议图标映射（模型层保持纯 Dart） |
| `lib/pages/home/home_page.dart` | 快捷网格 + 天气卡 emoji→Material 图标；海拔加载态 |
| `lib/pages/shared/weather_detail_page.dart` | 实时/小时/10 天/建议图标统一 |
| `lib/pages/shared/guide_page.dart` | 引导插画 emoji→Material 图标 |
| `lib/pages/discover/discover_page.dart` | 分类封面 / AI / Chip 图标统一 |
| `lib/pages/profile/favorites_page.dart`、`photo/photo_recognition_page.dart`、`shared/trajectory_page.dart`、`calendar/calendar_page.dart`、`food/food_detail_page.dart`、`oneday/oneday_page.dart` | 图标位统一 |
| `lib/pages/shared/splash_page.dart` / `profile_page.dart` | 版本号统一 |
| `lib/pages/discover/discover_page.dart` | AI 失败友好提示 |
| `lib/pages/profile/settings_page.dart` | 注销账号入口 + 两步确认 |
| `lib/services/auth_service.dart` | `deleteAccount()` 后端删除 + 清本地 |
| `lib/providers/app_providers.dart` | 海拔定位超时回退 |
| `scripts/build_channels.sh` / `build_channels.ps1` | 多渠道打包脚本 |
| `privacy_policy.html` | 可托管隐私政策 |
| `docs/RELEASE_CHANNELS.md` / `docs/IOS_RELEASE_CHECKLIST.md` / `docs/UI_AUDIT_2026-09-10.md` | 发布与审计文档 |

---

## [Unreleased] — 2026-09-10 功能界面优化（第二轮）

> 针对模拟器走查反馈的 4 处功能界面细节做定向优化。
> 静态检查 `flutter analyze` → No issues；`flutter test` **54 用例全绿**（含新增 4 个回归用例），
> 全路由溢出扫描（320~414 宽 × 10 尺寸）0 命中。

### Changed（优化）

- **首页 · 快捷功能**
  - 快捷功能图标整体放大：图标底容器 48 → 自适应 46~58（按列宽），图标本体 24 → 26~32。
  - 卡片内「快捷功能」标题与宫格间距：6 → 2，标题紧贴功能区。
  - 宫格高度改用 `mainAxisExtent`（= 图标容器 + 间隙 + 文字行高，行高随系统字号缩放），
    替掉固定 `childAspectRatio: 0.87` —— 窄屏 / 大字号下不再有被压扁溢出的风险。
- **发现页**
  - 「为你精选」标题与卡片间距调大：12 → 18。
  - 「分类」标题与卡片间距调小：8 → 4。
- **首页 · 天气卡片整卡可点**
  - 卡片内任意位置（温度、天气图标、湿度/风、今明温度块、日期副标题、上下留白）统一跳天气详情。
  - 修复根因：原先只有「天气 Row」被 `GestureDetector` 包住，且默认 `HitTestBehavior.deferToChild`
    只在子节点命中 —— 点日期副标题或卡片留白毫无反应；现由 `GradientHeader.onCardTap`
    以 `HitTestBehavior.opaque` 包住整卡，标题区（切城市）与刷新按钮层级更深、仍各自生效。
- **万年历**
  - 标题栏去掉「上个月 / 下个月」箭头（只留返回），切换功能下移到日历卡片顶部：
    左箭头 · 「今天」· 右箭头一行，紧贴网格、单手可达，避免同一功能两处入口。
  - 日期格顶部不再挂节日 / 休班角标（原 `maxWidth: 46`、`fontSize: 9` 的右上角胶囊）：
    格宽仅约 58px，角标会挤压日期数字；节日名已由下方农历小标签
    （节气 > 节日 > 初一月份 > 农历日）与老黄历卡片承载，不再三处重复。

### Added（新增测试）

- `test/home_weather_card_tap_test.dart`：天气卡底部留白 / 日期副标题点击跳天气详情；
  并守护「点城市名仍走切城市、不被整卡点击吞掉」（负向验证：注释 `onCardTap` 后前两个用例失败）。
- `test/calendar_month_nav_test.dart`：标题栏无月份箭头、卡片内有左右切换 + 「今天」；
  切换可改变月份；日期格不再出现「休」「班」角标，同时「中秋节」仍由农历标签呈现
  （固定 `initialDate=2026-09-25`，与「今天」无关）。

### 涉及关键文件

| 文件 | 改动 |
|------|------|
| `lib/pages/shared/widgets/common_widgets.dart` | `GradientHeader` 新增 `onCardTap`（opaque 整卡点击） |
| `lib/pages/home/home_page.dart` | 快捷网格图标放大 + 标题间距 2 + `mainAxisExtent` 自适应；天气卡 `onCardTap` |
| `lib/pages/discover/discover_page.dart` | 「为你精选」间距 12→18、「分类」间距 8→4 |
| `lib/pages/calendar/calendar_page.dart` | 月份切换下移到日历卡片内；日期格去掉假日角标 |
| `test/home_weather_card_tap_test.dart`、`test/calendar_month_nav_test.dart` | 新增回归用例（4 个） |

---

## [Unreleased] — 2026-09-10 休班标签置顶/行程页扩展 + 接口版本化（第五轮）

### Changed（优化）

- **休/班标签移到日期格顶部**：万年历日期格内「休/班」胶囊从底部移到顶部
  （用户实测后指定位置），带标签格子农历照旧让位。
- **行程页迷你日历同样显示休/班标签**：抽出共享组件
  `lib/pages/shared/widgets/arrangement_badge.dart`（红=休、橙=班、非当月降透明度），
  万年历与 `MiniCalendar` 共用；顺带修复迷你日历「调休补班的周末仍标红」的
  不一致（补班日本质是工作日，不该标红）。
- **接口版本化**：`AuthService.apiBase` 从裸路径切到 `{serverUrl}/api/v1`；
  服务端同时暴露两套路径，旧版本后端亦兼容（回退只需改 apiBase 一处）。
  所有业务请求（auth/trajectory/admin）与 `ping()` 健康检查路径一并核对。

### Added（新增）

- `test/mini_calendar_holiday_badge_test.dart`：迷你日历休/班标签测试。
- `test/api_base_versioning_test.dart`：apiBase 版本化路径测试。
- 万年历测试补「下月补位格同样显示休/班」用例（跨月假期覆盖）。

### 验证

`flutter analyze` 0 issue；`flutter test` 108 用例全绿（96 → 108）。

---

## [Unreleased] — 2026-09-10 云端足迹统计接入「我的」页（第四轮）

### Added（新增）

- `lib/models/cloud_stats.dart`：`CloudStats` 模型 —— 对接服务端 `GET /trajectory/stats`。
  - 单位严格沿用服务端契约（距离**米**、时长**秒**、时间戳**毫秒**），换算全部收敛到 `xxxText`，
    避免「数字看着都对、单位差 1000 倍」这类难以察觉的错误。
  - 解析**永不抛异常**：字段缺失/类型异常一律退化为 0 —— 统计属于锦上添花的信息，
    不能因为某个字段缺失就让「我的」页整块报错。
- `lib/pages/shared/widgets/cloud_stats_card.dart`：「云端足迹」卡片，五种状态都有明确呈现：
  加载（骨架占位）/ 未登录（整卡隐藏）/ 出错（可读文案 + 重试）/ 无数据（引导去同步）/ 正常。
- `SyncService.fetchStats()`：拉取汇总统计。服务端在 SQL 侧一次聚合后只回传一行，
  **调用代价与轨迹条数无关** —— 这是引入该接口的核心理由（轨迹会随使用时间累积，
  本地求和迟早拖慢页面）。
- `cloudStatsProvider`：`watch(authProvider)` 联动 —— 登录/退出后自动重取，页面无需手动 invalidate。
- 新增测试 34 例：`test/cloud_stats_test.dart`（23 例，解析容错 + 单位换算 + 时间展示）、
  `test/cloud_stats_card_test.dart`（11 例，五种状态 + 窄屏 320 溢出）。
- 工程工具（提交卫生）：
  - `scripts/install_git_filters.sh`：安装 + 自检 git clean filter（每台机器执行一次）。
    自检含**精确输出比对**（避免「空输出被误判为通过」），并用「add 进索引后断言 0 处注入」
    做决定性验证。
  - `scripts/git-htmlclean.sh`：clean filter 包装脚本（找不到 python 时原样透传，绝不阻断 git；
    可用 `MICROTRIP_PYTHON` 指定解释器）。
  - `.gitattributes`：filter 声明 + `*.sh text eol=lf`（CRLF 会把 `\r` 带进 shell 变量，
    导致路径解析失败 —— 本地已踩过同类坑）。

### Changed（优化）

- 「我的」页在功能入口之前插入云端足迹卡片；`localRecordCount` 传入本地条数，
  云端与本地不一致时给出**原因解释**（「比本地多 N 条（含其他设备）」/「少 N 条（未同步）」），
  避免用户误以为数据丢失。
- 同步完成（`settings_page.dart`）、删除云端记录（`cloud_trajectory_page.dart`、
  `trajectory_detail_page.dart::fromCloud`）后 `invalidate(cloudStatsProvider)` ——
  统计由服务端聚合、客户端无法本地推算，不失效会让用户看到改动前的数字。
- `cloud_trajectory_page.dart` 由 `StatefulWidget` 改为 `ConsumerStatefulWidget`（仅为拿到 `ref`）。

### 涉及关键文件

| 文件 | 改动 |
|------|------|
| `lib/models/cloud_stats.dart` | 新增：统计模型 + 格式化 + 解析容错 |
| `lib/pages/shared/widgets/cloud_stats_card.dart` | 新增：五态统计卡片 |
| `lib/services/sync_service.dart` | 新增 `fetchStats()` |
| `lib/providers/app_providers.dart` | 新增 `cloudStatsProvider`（联动登录态） |
| `lib/pages/profile/profile_page.dart` | 接入卡片 |
| `lib/pages/profile/settings_page.dart` | 同步后刷新统计；地址提示补充明文说明 |
| `lib/pages/trajectory/cloud_trajectory_page.dart` | 转 Consumer + 删除后刷新统计 |
| `lib/pages/trajectory/trajectory_detail_page.dart` | 云端删除后刷新统计 |
| `android/app/src/debug/AndroidManifest.xml` | 新增 debug 明文许可（release 不受影响） |
| `android/app/src/debug/res/xml/network_security_config_debug.xml` | 新增 |
| `lib/services/auth_service.dart` | `ping()` 在正式包对 `http://` 给出明确提示 |
| `scripts/shots.py` | 新增：模拟器走查截图工具 |
| `.gitattributes` | 新增：`privacy_policy.html` clean filter + `*.sh` 锁 LF |
| `scripts/git-htmlclean.sh` | 新增：clean filter 包装（无 python 时透传） |
| `scripts/install_git_filters.sh` | 新增：安装 + 自检 filter |
| `scripts/clean_html_injection.py` | 增加 `--stdin` 过滤模式（供 git filter 调用） |
| `test/cloud_stats_test.dart`、`test/cloud_stats_card_test.dart` | 新增（34 例） |

### Fixed（修复）

- **debug 包无法访问 `http://` 后端**：主清单未放开明文，而 targetSdk ≥ 28 时 Android 默认禁止
  明文 HTTP，导致本地联调只能看到笼统的「网络错误」。已加 **debug 专用**网络安全配置。
- **正式包填 `http://` 地址会静默失败**：`AuthService.ping()` 现在会区分「地址填错」与
  「被系统明文策略拦截」，直接给出可操作文案，避免用户在地址上反复试错。
- **`privacy_policy.html` 被 IDE 预览持续回写注入属性**：提交后再复现一次，且实测
  `git checkout` 恢复后 **2 秒内又会被重新注入 37 处** `data-page-node-id` —— 手工
  「提交前记得跑一次脚本」已经防不住这类合规文件被污染。改为 **git clean filter 自动剥离**：
  `.gitattributes` 声明 `privacy_policy.html filter=htmlclean`，配合
  `scripts/git-htmlclean.sh` + `scripts/install_git_filters.sh`（每台机器执行一次）。
  效果：工作区可以保持被注入的样子，`git status` 不再出现该幽灵改动，`git add` 写入索引的
  内容 0 处注入。filter 找不到可用 python 时**原样透传**（退回旧行为），绝不阻断 git。

### 走查记录（模拟器实机，2026-09-10）

`build/audit_shots/` 新增 4 张：`26_calendar_holiday_badges`（9 月休/班）、
`27_calendar_oct_holiday`（10 月国庆连休 + 补班）、`28_profile_logged_out`（未登录卡片隐藏）、
`29_profile_cloud_stats`（云端足迹真实数据）。逐像素核对了「补班日数字不标红」与
「假期周末数字标红 + 红休」两个易看走眼的细节。详见 `docs/UI_AUDIT_2026-09-10.md` 第七章。

---

## [Unreleased] — 2026-09-10 真实联系邮箱 + 万年历休班标签（第三轮）

### Added（新增）

- `AppConfig.contactEmail`：联系邮箱单点常量（隐私政策页 / 用户协议页 / 上架文档统一引用）。
- `test/calendar_holiday_badge_test.dart`（5 例）：休/班标签优先级、配色、补班日数字配色、跨月补位格。
- `test/config_contact_email_test.dart`（3 例）：邮箱为真实可投递地址、两协议页正文确实引用该常量、无占位邮箱残留。

### Changed（优化）

- **万年历日期格底部标签**：法定放假 / 调休补班时显示「休 / 班」胶囊，**优先级高于农历日期**
  （原第二轮把角标整体移除，本轮按要求回到「底部小标签」位，不再挤压日期数字）。
  - `休` → 红色胶囊；`班` → 橙色胶囊；非本月补位格降透明度。
  - 一致性修正：**调休补班的周末，日期数字不再标红**（补班是工作日，标红自相矛盾）。

### Fixed（修复）

- 「隐私政策」「用户协议」正文与页脚的联系邮箱由占位地址 `privacy@microtrip.example`
  替换为 `xuhaijun5382@163.com`（含根目录 `privacy_policy.html`），满足渠道审核对「可联系到运营方」的要求。

### 涉及关键文件

| 文件 | 改动 |
|------|------|
| `lib/core/config/app_config.dart` | 新增 `contactEmail` 常量 |
| `lib/pages/profile/privacy_policy_page.dart` | 两处邮箱改为引用常量 |
| `lib/pages/profile/user_agreement_page.dart` | 邮箱改为引用常量 |
| `lib/pages/calendar/calendar_page.dart` | 日期格底部新增 `_buildArrangementBadge`；补班日数字配色修正 |
| `privacy_policy.html` | 托管版隐私政策邮箱同步替换 |
| `docs/RELEASE_CHANNELS.md` | 上架清单邮箱项标记完成 |

---

## [Phase 5] — 云端同步与后台录制（历史）

- 后端服务 MicroTripServer（Node.js + Express + SQLite）：JWT 认证 + 轨迹同步 API。
- 云端同步（手动同步 + 云端历史列表/详情下载）。
- 后台轨迹录制（`flutter_background_service` 前台 Service 保活）。
- UI 动效升级（8 处进场/交错/数值滚动）。
- Release 签名构建（keystore + `build.gradle.kts` 接入 + 脱糖，签名 APK 63 MB / V2）。

详见 `overview.md` 与 `README.md` Phase 1–5。

[Unreleased]: https://github.com/xuhaijun/MicroTrip/compare
