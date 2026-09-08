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

## [Phase 5] — 云端同步与后台录制（历史）

- 后端服务 MicroTripServer（Node.js + Express + SQLite）：JWT 认证 + 轨迹同步 API。
- 云端同步（手动同步 + 云端历史列表/详情下载）。
- 后台轨迹录制（`flutter_background_service` 前台 Service 保活）。
- UI 动效升级（8 处进场/交错/数值滚动）。
- Release 签名构建（keystore + `build.gradle.kts` 接入 + 脱糖，签名 APK 63 MB / V2）。

详见 `overview.md` 与 `README.md` Phase 1–5。

[Unreleased]: https://github.com/xuhaijun/MicroTrip/compare
