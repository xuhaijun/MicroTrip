# 微旅途 · 应用商店发布检查清单（Phase 4）

> 本清单涵盖 **Android**（华为应用市场 / 小米 / OPPO / vivo / Google Play）与 **iOS**（App Store）双平台发布所需全部配置、权限说明与操作步骤。
>
> 当前状态：图标已生成，签名已配置（release keystore），Release APK 已构建验证（63 MB，V2 签名）。

---

## 一、图标生成（已完成）

| 平台               | 状态 | 说明                                                                                                  |
| ---------------- | -- | --------------------------------------------------------------------------------------------------- |
| Android legacy   | ✅  | mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi (48/72/96/144/192 px)                                         |
| Android adaptive | ✅  | `mipmap-anydpi-v26/ic_launcher.xml` + `drawable-*/ic_launcher_foreground.png` + `values/colors.xml` |
| iOS AppIcon      | ✅  | 15 个独立尺寸（含 iPhone / iPad / App Store 1024px），alpha 已移除                                              |

**源图**：`assets/images/logo.png`（1024×1024，蓝色底 + 白定位标）  
**Android 自适应背景色**：`#4FC3F7`（写入 `colors.xml`）  
**iOS 背景色**：`#4FC3F7`（与 Android 统一品牌色）

> 注：由于 Windows 实时扫描会锁定刚写入的 PNG，本地直接运行 `flutter_launcher_icons` 可能失败。本项目通过 Python/Pillow 脚本补齐了缺失的 `xxxhdpi` 与 iOS 图标，并创建了自适应 XML。

---

## 二、Android Release 签名配置（已完成）

> ✅ Phase 5 已落地：release keystore 已生成于 `android/app/keystore/release.keystore`，  
> `key.properties`（gitignored）已写入，`build.gradle.kts` 的 release signingConfig 已启用，  
> 并已构建出签名 APK（V2 方案，证书 CN=Xuhaijun / OU=MicroTrip / O=Genvict）。

### 2.1 生成 keystore

在项目根目录执行：

```bash
cd android/app
keytool -genkey -v \
  -keystore keystore/release.keystore \
  -alias release \
  -keyalg RSA -keysize 2048 -validity 10000
```

按提示填写：

- 密钥库密码（例如：`MicroTrip2026`）
- 密钥密码（可与库密码相同）
- 组织信息（姓名、组织单位、城市、省份、国家代码 `CN`）

### 2.2 创建 key.properties（不加入 git）

创建 `android/keystore/key.properties`：

```properties
storeFile=keystore/release.keystore
storePassword=你的密钥库密码
keyAlias=release
keyPassword=你的密钥密码
```

> ⚠️ **安全警告**：`key.properties` 与 `*.keystore` 必须加入 `.gitignore`，绝对不要提交到仓库！

### 2.3 启用 build.gradle.kts 签名块

取消 `android/app/build.gradle.kts` 中「发布签名配置」段落的注释，使 Gradle 读取 `key.properties`。

### 2.4 验证签名

```bash
# 构建 release APK
flutter build apk --release

# 查看签名信息
keytool -list -v -keystore android/app/keystore/release.keystore

# 校验 APK 签名方案（应 Verified using v2 scheme: true）
$ANDROID_HOME/build-tools/<ver>/apksigner.bat verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

### 2.5 路径编码避坑（已规避）

本项目当前位于 **ASCII 路径** `D:\FlutterProjects\MicroTrip`，`flutter build apk --release` 的  
**AOT 快照阶段**（`gen_snapshot` 读取 `app.dill`）**不会因中文路径乱码失败**，**可直接在原目录执行 Release 构建**，  
无需 ASCII 副本或系统 UTF-8 配置。

> **历史背景（供含中文路径的项目参考）**：早期项目位于 `D:\微旅途Flutter版\...` 时，Windows 默认 GBK 编码会  
> 把中文路径误解码（表现为 `Unable to read file: D:\微锟斤拷途...app.dill` → AOT snapshotter exit 255），debug 不受影响。  
> 当时两种方案：① 系统级启用「Beta: 使用 Unicode UTF-8」（重启生效）；② 复制到 ASCII 路径**真实副本**  
> （`robocopy` 排除 `build/.dart_tool/.git`，junction 会被 Flutter 解析回真实路径而失效）。现项目已迁移到 ASCII 路径，上述方案不再需要。

> 另外，Phase 4 引入的 `flutter_local_notifications` 依赖 Java 8+ API，  
> `build.gradle.kts` 已启用 `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs")`，  
> 否则 `checkReleaseAarMetadata` 会因「requires core library desugaring」失败。

---

## 三、权限清单与披露要点（双平台）

> 权限用途声明已与代码逐一核对（2026-08-24）：Android `AndroidManifest.xml` 与 iOS `Info.plist` 中定位 / 健康 / 通知等关键权限声明**全部齐全**，且与功能实际调用一致，无多余权限。

### 3.1 Android（android/app/src/main/AndroidManifest.xml）

| 权限                                                   | 用途                               | 敏感        | 用户可见说明（填商店后台用）     |
| ---------------------------------------------------- | -------------------------------- | --------- | ------------------ |
| `INTERNET`                                           | 加载在线地图瓦片、天气 / AI 联网              | 否         | 获取在线天气与地图数据        |
| `ACCESS_FINE_LOCATION`                               | GPS 轨迹录制（geolocator）             | 是         | 出行轨迹精准定位记录         |
| `ACCESS_COARSE_LOCATION`                             | WLAN / 基站定位兜底                    | 否         | 弱网场景位置辅助           |
| `ACCESS_BACKGROUND_LOCATION`                         | 退后台 / 锁屏持续 GPS 录制（Phase 5 启用）    | **是（重点）** | 后台持续记录出行轨迹，保证轨迹完整  |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_LOCATION` | 轨迹录制保活前台 Service（Android 14+ 必需） | 否         | 轨迹录制前台服务保活         |
| `POST_NOTIFICATIONS`                                 | 每日天气提醒（Android 13+）              | 是         | 每日早晨天气提醒（可开关）      |
| `RECEIVE_BOOT_COMPLETED`                             | 重启后恢复定时通知                        | 否         | 重启后恢复天气提醒日程        |
| `health.READ_STEPS`                                  | 读 Health Connect 今日步数            | 是         | 同步系统步数到今日统计（授权后可用） |

**Google Play 重点披露**：`ACCESS_BACKGROUND_LOCATION` 属敏感权限，提交 Data Safety / 权限用途时**必须**说明仅用于「轨迹录制时后台持续定位」，并需在 Play Console 上传 30–60s 演示视频展示后台定位触发场景，否则极易被拒。

**无需声明但涉及的能力**：

- `CAMERA` / `READ_MEDIA_IMAGES`：`image_picker` 通过系统 Intent 调用相机 / 相册，不直接申请权限。

### 3.2 iOS（ios/Runner/Info.plist）

| Key                                            | 用途                                              | 状态                                            |
| ---------------------------------------------- | ----------------------------------------------- | --------------------------------------------- |
| `NSLocationWhenInUseUsageDescription`          | 使用中 GPS 轨迹录制                                    | ✅ 已声明                                         |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | 后台 / 锁屏持续录制                                     | ✅ 已声明                                         |
| `UIBackgroundModes: location / fetch`          | 后台持续位置 + 后台刷新                                   | ✅ 已声明                                         |
| `NSHealthShareUsageDescription`                | 读取健康步数（仅读，故无需 `NSHealthUpdateUsageDescription`） | ✅ 已声明                                         |
| `NSCameraUsageDescription`                     | 拍照识物                                            | ✅ 已声明                                         |
| `NSPhotoLibraryUsageDescription`               | 相册选图识物                                          | ✅ 已声明                                         |
| `NSPhotoLibraryAddUsageDescription`            | —                                               | ❌ **不声明**：截图分享走 `share_plus` 系统分享面板，App 不直写相册 |
| 通知权限                                           | iOS 通知无需 plist key，由系统弹窗                        | ✅ 无需声明                                        |

### 3.3 隐私合规落地状态

| 合规项                        | 状态    | 说明                                                                                            |
| -------------------------- | ----- | --------------------------------------------------------------------------------------------- |
| 应用内「隐私政策」页                 | ✅ 已完成 | `privacy_policy_page.dart` + `user_agreement_page.dart`；入口在「关于」页与设置页底部；首启弹《用户协议 & 隐私政策》征询框    |
| 首次调用授权说明                   | ✅ 已完成 | 定位 / 健康未授权时服务层静默失败 + 降级；`permission_manage_page.dart`「去授权」按钮引导；系统原生弹窗配合上述 plist / manifest 文案 |
| 隐私清单 PrivacyInfo.xcprivacy | ⚠️ 待补 | iOS 17+ / Xcode 15 起要求，见第四章节                                                                  |

**地图瓦片 Key（天地图 tk）— 部署硬性前置**：

- `lib/core/config/app_config.dart` 的 `tdtKey` 目前为占位符（`'在此填写你的天地图tk'`），**必须**替换为真实 tk（天地图控制台 <https://console.tianditu.gov.cn/api/key> 创建「浏览器端」应用）。
- 瓦片 URL 在编译期拼入 `tk`，未配置时地图瓦片全部 403 空白；替换后**必须重新构建**（debug 热重载不生效）。
- 天地图坐标系为 CGCS2000 ≈ WGS-84，App 内坐标无需转换；若换回高德/腾讯瓦片则需恢复 GCJ-02 转换（见 `docs/architecture.md` §5.23）。

---

## 四、iOS 发布检查项

| 检查项                    | 状态 | 说明                                                                                                            |
| ---------------------- | -- | ------------------------------------------------------------------------------------------------------------- |
| AppIcon.appiconset     | ✅  | 全部 15 张图标已生成，Contents.json 已包含 iPhone/iPad/marketing                                                          |
| 启动图（LaunchScreen）      | ⚠️ | 默认使用 Flutter 生成的 `LaunchScreen.storyboard`，如需品牌定制请替换背景色或添加 Logo                                               |
| `Info.plist` 权限说明      | ✅  | 定位 / 健康 / 相机 / 相册权限全部声明，详见第三节 3.2（通知无需 plist key；`NSPhotoLibraryAddUsageDescription` 因走 `share_plus` 系统分享不声明） |
| 通知权限（iOS）              | ✅  | `flutter_local_notifications` 初始化时通过 `DarwinInitializationSettings` 自动申请 Alert/Badge/Sound                    |
| 后台模式                   | ✅  | `UIBackgroundModes: location / fetch` 已在 Info.plist 声明（后台轨迹录制用 location；`fetch` 用于后台刷新）                       |
| 隐私清单（Privacy Manifest） | ⚠️ | iOS 17+ / Xcode 15 起要求 `PrivacyInfo.xcprivacy`；当前未添加，App Store 审核时可能要求补录第三方 SDK 的隐私追踪说明                       |

**iOS 构建命令**：

```bash
flutter build ios --release
# 打开 Xcode 归档：open ios/Runner.xcworkspace
# Product > Archive > Distribute App
```

---

## 五、版本号管理

版本号在 `pubspec.yaml` 顶部定义：

```yaml
version: 3.0.0+1
# 格式：versionName+versionCode
# Android versionCode 必须每次发布递增
# iOS CFBundleVersion 同步使用 buildNumber
```

| 发布轮次  | 建议 version   | versionCode |
| ----- | ------------ | ----------- |
| 内测/灰度 | 1.0.0-beta+1 | 1           |
| 正式首版  | 1.0.0+2      | 2           |
| 迭代更新  | 1.0.1+3      | 3           |

---

## 六、构建产物与体积预估

```bash
# Android APK（国内分发，未拆分 ABI）
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
# 实测体积：~63 MB（含 Flutter 引擎 + flutter_map/地图瓦片缓存 + 脱糖运行时 + 资源）

# Android App Bundle（Google Play 必备）
flutter build appbundle --release
# 产物：build/app/outputs/bundle/release/app-release.aab

# iOS 归档（需在 macOS + Xcode 下执行）
flutter build ios --release
```

---

## 七、上架材料准备

### 通用素材

| 素材       | 规格                                               | 状态  |
| -------- | ------------------------------------------------ | --- |
| 应用名称     | 微旅途                                              | ✅   |
| 应用简介     | 一句话：「微旅途——你的智能出行助手，实时天气、AI 行程规划、轨迹记录、拍照识物一站式搞定。」 | 待补充 |
| 详细描述     | 功能亮点（天气/AI/轨迹/美食/景点/万年历/步数）+ 使用场景                | 待补充 |
| 应用截图     | 5 张以上，涵盖首页/天气/行程/AI 聊天/我的                        | 待截图 |
| 隐私政策 URL | 可使用腾讯文档 / GitHub Pages 托管                        | 待创建 |
| 开发者资质    | 企业/个人营业执照或身份证                                    | 待准备 |

### Android 各渠道额外要求

- **华为应用市场**：需软件著作权或《电子版权证书》；要求 64 位 so 库（Flutter 默认输出含 arm64-v8a）。
- **小米**：需《计算机软件著作权登记证书》或测试账号；应用内必须含有「账号注销」功能（当前已支持退出登录/清除数据）。
- **OPPO / vivo**：类似要求，注意各渠道包名不可冲突（统一使用 `com.xuhai.micro_trip`）。
- **Google Play**：需 aab 格式；targetSdk 需符合最新政策；需填写数据安全表单（Data Safety）。

### iOS App Store 额外要求

- 截图尺寸：iPhone 6.7" / 6.5" / 5.5" 三套 + iPad 12.9" 一套
- 预览视频（可选）
- 分级（App 分级）：建议 4+（无暴力、无赌博）
- 帐号登录 / 注册：苹果要求提供「测试账号」供审核员登录体验；当前本地演示模式已支持任意手机号注册。

---

## 八、最终上架前检查清单

- [ ] `pubspec.yaml` version 已递增
- [ ] 天地图 tk 已配置（`app_config.dart` 的 `tdtKey`），地图瓦片正常加载（非 403）
- [ ] Android keystore 已生成且 `key.properties` 已配置
- [ ] `build.gradle.kts` release signingConfig 已启用
- [ ] `AndroidManifest.xml` 权限与实际功能一一对应，无多余权限
- [ ] Android / iOS 图标在各设备/模拟器上显示正常
- [ ] 冷启动无崩溃，首页天气加载正常
- [ ] 登录/注册流程正常（本地模式 + 后端模式均验证）
- [ ] 轨迹录制 > 保存 > 详情 > 截图分享链路正常
- [ ] 天气提醒通知开关可正常开启/关闭，定时调度无崩溃
- [ ] 步数统计在授权后显示真实数据，未授权时自动降级 mock
- [ ] 隐私政策页面已上线且 URL 已填入各商店后台
- [ ] 各渠道「测试账号」已准备（手机号 + 密码）
- [ ] Release APK / AAB / IPA 已通过安装测试

---

*文档版本：v1.2*  
*对应代码版本：Phase 5 完成；2026-08-24 补充双平台权限披露要点（第三节）并修正 iOS 后台模式状态*
