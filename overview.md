# 微旅途 Flutter 版 — Phase 5 完成总结

## 交付概览

Phase 5 范围：云端同步（新建 MicroTripServer 后端 + App 手动同步 + 云端历史）、后台轨迹录制、UI 动效升级、Release 签名构建。全部子任务已完成，#35–#42 清零，项目累计 42 个任务全部交付。

---

## 核心新增

### 1. 双模式认证体系（JWT 登录）
- `lib/services/auth_service.dart`：本地 Mock（HS256 签发 JWT，30 天有效，纯 Dart `crypto` 包）+ 可切换真实后端（设置页配置 `serverUrl`）。
- `lib/models/user_profile.dart`：不可变用户模型。
- `lib/providers/auth_provider.dart`：登录态 Riverpod 状态层。
- `lib/pages/profile/login_page.dart`：登录/注册 Tab 切换页。
- `lib/pages/profile/profile_page.dart`：用户卡登录态感知（头像/昵称/脱敏手机号/退出）。
- `lib/core/http/http_client.dart`：鉴权拦截器升级 — `tokenProvider` 注入 Bearer Token + `onUnauthorized` 全局 401 处理（清会话 + 跳登录页）。

### 2. 系统健康步数（iOS HealthKit / Android Health Connect）
- `lib/services/health_service.dart`：封装 `health: ^13.3.1` singleton API，静默读取今日/历史步数，未授权返回 null（由 `StepService` 自动降级 mock）。
- `lib/services/step_service.dart`：数据源优先级链 — 健康平台 > 本地缓存 > mock。
- 平台配置：Android minSdk=26 + `health.READ_STEPS` + 应用探测；iOS `NSHealthShareUsageDescription`。

### 3. 每日天气本地通知
- `lib/services/weather_push_service.dart`：`flutter_local_notifications` 每日 08:00 `zonedSchedule`（`matchDateTimeComponents: DateTimeComponents.time` 每日重复），内容用最新天气实时组装。
- `lib/pages/profile/settings_page.dart`：新增「每日天气提醒」开关（即时生效）。
- `main.dart`：启动时后台异步初始化通知插件并恢复调度。

### 4. 应用图标与发布清单
- Android：legacy icons（48/72/96/144/192 px）+ adaptive icon（foreground + background `#4FC3F7`）+ `mipmap-anydpi-v26/ic_launcher.xml`。
- iOS：15 张 AppIcon（品牌蓝背景，alpha 已移除），满足 App Store 规范。
- `RELEASE.md`：完整上架检查清单（签名配置步骤、权限说明、各商店要求、构建命令、素材准备）。
- `android/app/build.gradle.kts`：release 签名配置模板（注释态，待启用）。

---

## Phase 5 核心新增

### 5. 后端服务 MicroTripServer（Node.js + Express + SQLite）
- `D:\FlutterProjects\MicroTripServer`：Express 5 + 内置 `node:sqlite`（DatabaseSync，零原生依赖，规避 better-sqlite3 段错误）+ `jsonwebtoken` HS256 + `bcryptjs`。
- 认证：`auth/register|login|logout`，轨迹：`trajectory/sync`(幂等 upsert) / `list`(分页) / `:id`(详情/删除)，全部 `requireAuth`；统一错误 `{error:{code,message}}`。

### 6. 云端同步与历史列表（App 端）
- `lib/services/sync_service.dart`：组装 `{trajectory: record.toMap()}` 上传，无后端优雅降级。
- `lib/models/cloud_trajectory.dart`：云端轨迹摘要模型。
- `lib/pages/trajectory/cloud_trajectory_page.dart`：云端历史列表 + 详情下载。
- `lib/pages/profile/settings_page.dart`：新增「数据同步」区块（手动同步按钮 + 状态反馈 + 云端历史入口）。

### 7. 后台轨迹录制
- `lib/services/background_recorder_service.dart`：`flutter_background_service` 前台 Service 保活（Android 14 `foregroundServiceType=location` + 常驻通知图标 `ic_bg_service_small`）。
- `AndroidManifest.xml`：`ACCESS_BACKGROUND_LOCATION` + `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION`。

### 8. UI 动效升级
- `lib/core/animations/anim_effects.dart`：动效组件库，植入首页 / 我的页 / 轨迹录制页 / 轨迹历史页共 8 处（进场、交错排列、数值滚动）。

### 9. Release 签名构建
- `android/app/keystore/release.keystore`（RSA 2048 / 10000 天）+ `key.properties`（gitignored）。
- `android/app/build.gradle.kts`：release signingConfig 启用 + `isCoreLibraryDesugaringEnabled`（flutter_local_notifications 脱糖）。
- ✅ 已产出签名 `app-release.apk`（63 MB，V2 签名，证书 CN=Xuhaijun）。**注意**：中文路径下 release AOT 需从 ASCII 副本构建（见 `RELEASE.md` §2.5）。

---

## 质量验证

- `dart analyze`（真实项目）：**No issues found!**（Phase 5 全量代码通过）。
- 后端冒烟测试：注册 201 / 重复 409 / 错误密码 401 / 登录签发 token / 无 token 401 / 同步 200 / 幂等 200 / 列表 total=1 / 删除后 total=0 —— 全绿。
- Release 构建：项目现位于 ASCII 路径 `D:\FlutterProjects\MicroTrip`，可直接 `flutter build apk --release` 产出签名 APK（V2 方案 verified；历史中文路径坑见 RELEASE.md §2.5）。
- Phase 4 验证回顾：`dart analyze` 0 issues；APK 构建此前因实时扫描锁文件受阻，现已在 Phase 5 通过 ASCII 路径构建绕过。

---

## 关键修复与改进

| 文件 | 修复内容 |
|------|----------|
| `health_service.dart` | `hasPermissions` 返回 `bool?` 归一化；`getHealthDataFromTypes` 参数改为 `startTime`/`endTime`；value 转型 `NumericHealthValue.numericValue` |
| `auth_service.dart` | 移除 9 处 `const ServiceException`；删除未使用 `app_config` 导入；修正 unnecessary braces |
| `weather_push_service.dart` | `initialize(settings:)` / `cancel(id:)` 修正为命名参数；`CityInfo` 移除 `const` |
| `login_page.dart` | 删除未使用 `common_widgets` 导入 |

---

## 文档更新

- `docs/architecture.md`：追加 Phase 4 设计决策（5.14–5.17）+ Phase 5 设计决策（5.18 后端 MicroTripServer、5.19 云端同步、5.20 后台录制、5.21 UI 动效、5.22 Release 签名构建）+ 目录结构与状态表更新。
- `RELEASE.md`：签名配置标记已完成，新增 §2.5 中文路径 Release 构建避坑（ASCII 副本 / 系统 UTF-8 / 脱糖），修正体积与后台定位说明。
- `README.md`：补 Phase 4 / Phase 5 功能表 + 后端技术栈 + Roadmap 收尾。
- `docs/Flutter开发环境搭建指南.html`：新增 Gradle 全局 init.gradle 与 Gradle 9 仓库模式冲突、APK 构建实战配置、init.gradle 兼容写法。
- `.workbuddy/memory/2026-08-20.md`：今日工作日志。
