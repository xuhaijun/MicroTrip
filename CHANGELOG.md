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
- 首页快捷操作网格 8 个 emoji 图标 → 统一 Material 线性图标（风格一致，更专业）。

### 涉及关键文件

| 文件 | 改动 |
|------|------|
| `lib/pages/home/home_page.dart` | 快捷网格 emoji→Material 图标；海拔加载态 |
| `lib/pages/shared/splash_page.dart` / `profile_page.dart` | 版本号统一 |
| `lib/pages/discover/discover_page.dart` | AI 失败友好提示 |
| `lib/pages/profile/settings_page.dart` | 注销账号入口 + 两步确认 |
| `lib/services/auth_service.dart` | `deleteAccount()` 后端删除 + 清本地 |
| `lib/providers/app_providers.dart` | 海拔定位超时回退 |
| `scripts/build_channels.sh` / `build_channels.ps1` | 多渠道打包脚本 |
| `privacy_policy.html` | 可托管隐私政策 |
| `docs/RELEASE_CHANNELS.md` / `docs/IOS_RELEASE_CHECKLIST.md` / `docs/UI_AUDIT_2026-09-10.md` | 发布与审计文档 |

---

## [Phase 5] — 云端同步与后台录制（历史）

- 后端服务 MicroTripServer（Node.js + Express + SQLite）：JWT 认证 + 轨迹同步 API。
- 云端同步（手动同步 + 云端历史列表/详情下载）。
- 后台轨迹录制（`flutter_background_service` 前台 Service 保活）。
- UI 动效升级（8 处进场/交错/数值滚动）。
- Release 签名构建（keystore + `build.gradle.kts` 接入 + 脱糖，签名 APK 63 MB / V2）。

详见 `overview.md` 与 `README.md` Phase 1–5。

[Unreleased]: https://github.com/xuhaijun/MicroTrip/compare
