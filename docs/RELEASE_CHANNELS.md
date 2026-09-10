# 微旅途 MicroTrip —— 多渠道打包与发布指南

> 适用版本：v3.0.0　最后更新：2026-09-10

## 1. 渠道产物

构建脚本 `scripts/build_channels.sh`（Windows Git Bash 直接跑；已规避 PowerShell 下 `flutter.bat` 缺
`ProgramFiles` 环境变量的坑，改用 `env` 注入）。产物统一输出到 `build/channels/`：

| 文件 | 渠道 | 用途 |
|------|------|------|
| `microtrip-3.0.0-huawei.apk` | huawei | 华为应用市场 |
| `microtrip-3.0.0-xiaomi.apk` | xiaomi | 小米应用商店 |
| `microtrip-3.0.0-oppo.apk`   | oppo   | OPPO 软件商店 |
| `microtrip-3.0.0-vivo.apk`   | vivo   | vivo 应用商店 |
| `microtrip-3.0.0-googleplay.aab` | googleplay | Google Play（AAB 格式） |
| `microtrip-3.0.0-official.apk` | official | 官网/直装（可选，CHANNEL=official） |

渠道号在 App 内通过 `AppConfig.channel` 读取（`String.fromEnvironment('CHANNEL')` 编译期注入），
关于页可见，便于统计各渠道来源。

### 重新构建
```bash
# 全部渠道（APK + AAB），后台运行（release 含 R8 混淆，单渠道约 15~45 分钟）
bash scripts/build_channels.sh

# 仅指定渠道
bash scripts/build_channels.sh xiaomi,oppo,vivo

# 仅 AAB
bash scripts/build_channels.sh aab
```

## 2. 各商店提交流程（要点）

### 华为应用市场（AppGallery）
- 注册/登录 [华为开发者联盟](https://developer.huawei.com/consumer/cn/)
- 创建应用 → 上传 `microtrip-3.0.0-huawei.apk`
- 必填：应用名称、分类、ICP 备案号（国内）、隐私政策 URL（见 §4）、截图（手机 3~5 张）
- 注意：华为对「定位/健康」权限有单独声明，按后台提示补《权限使用说明》

### 小米应用商店
- 注册/登录 [小米开放平台](https://dev.mi.com/)
- 上传 `microtrip-3.0.0-xiaomi.apk`
- **强制要求账号注销入口**（已内置：设置 → 账号与后端服务 → 注销账号，含两步确认）
- 必填：隐私政策 URL、截图、应用图标（512×512）、软著或免责声明

### OPPO 软件商店
- 注册/登录 [OPPO 开放平台](https://open.oppomobile.com/)
- 上传 `microtrip-3.0.0-oppo.apk`
- 必填：隐私政策 URL、权限声明、截图

### vivo 应用商店
- 注册/登录 [vivo 开放平台](https://dev.vivo.com.cn/)
- 上传 `microtrip-3.0.0-vivo.apk`
- 必填：隐私政策 URL、截图、ICP 备案

### Google Play
- [Play Console](https://play.google.com/console/) 创建应用
- 上传 `microtrip-3.0.0-googleplay.aab`（**必须 AAB**）
- 必填：隐私政策 URL、数据安全表单（Data safety）、分级问卷、截图（含 7" 平板）
- 注意：国内四家渠道的 APK 不要上传到 Play，避免重复/混淆

## 3. 上架素材清单（需人工准备）

- [ ] 应用图标 512×512（已生成于 `android/app/src/main/res/mipmap-*`）
- [ ] 商店截图各 3~5 张（建议真机/模拟器截取核心页：首页、天气、行程、AI、我的）
- [ ] 应用简介（一句话 + 详细说明）
- [ ] 隐私政策 URL（见 §4）
- [ ] 用户协议 URL（建议与隐私政策同源，另建 `user_agreement.html`）
- [ ] ICP 备案号 / 软著（国内渠道硬性要求，需运营方提供）
- [ ] 联系邮箱（替换 `privacy@microtrip.example` 为真实地址）

## 4. 隐私政策托管（满足渠道后台 URL 要求）

仓库已提供可托管 HTML：`privacy_policy.html`（根目录，内容与 App 内《隐私政策》页一致）。

**最省事方案：Gitee Pages**（你已有 `ecloudy/micro-trip` 仓库）
1. 将本仓库（含 `privacy_policy.html`）推到 Gitee
2. Gitee 仓库页 → 服务 → Gitee Pages → 部署 `master` 分支根目录
3. 获得 `https://ecloudy.gitee.io/micro-trip/privacy_policy.html` 填入各商店后台

> 亦可发布到 GitHub Pages、对象存储（COS/OSS）或自有服务器。
> 联系邮箱已统一为 `xuhaijun5382@163.com`（Flutter 侧单点定义在 `AppConfig.contactEmail`，
> 换邮箱只需改这一处 + 本 HTML）。

## 5. iOS 发布（本机 Windows 无法构建，需在 Mac 完成）

详见 `docs/IOS_RELEASE_CHECKLIST.md`。要点：
- 本仓库已补齐 `ios/Runner/PrivacyInfo.xcprivacy`（Apple 隐私清单，2024-05 起强制）
- Mac 上 `flutter build ios` → Xcode Archive → 上传 App Store Connect
- 证书/描述文件需 Mac 端登录开发者账号配置
