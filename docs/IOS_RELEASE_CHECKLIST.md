# iOS 上架归档清单（Mac 侧执行）

> 背景：本机为 Windows，**无法构建/归档 IPA**（需 macOS + Xcode）。
> 本清单列出在 Mac 上需要完成的最后几步；代码侧配置已全部就绪（见 §1）。

---

## 1. 代码侧已就绪（Windows 侧已完成 ✅）

| 项 | 状态 | 位置 |
|----|------|------|
| 定位权限文案（前台/后台） | ✅ | `ios/Runner/Info.plist` |
| 健康步数权限文案（HealthKit） | ✅ | `ios/Runner/Info.plist` |
| 相机/相册权限文案 | ✅ | `ios/Runner/Info.plist` |
| 后台模式（location/fetch）+ BGTaskScheduler | ✅ | `Info.plist` + `BackgroundLocationManager.swift` |
| App 图标 15 尺寸（品牌蓝，无 alpha） | ✅ | `ios/Runner/Assets.xcassets/AppIcon.appiconset` |
| **隐私清单 PrivacyInfo.xcprivacy**（Apple 2024-05 强制） | ✅ 新增 | `ios/Runner/PrivacyInfo.xcprivacy` |

## 2. Mac 侧待执行（按顺序）

1. **拉取最新代码**：`git pull`（含本次新增的 `PrivacyInfo.xcprivacy`）。
2. **把隐私清单加入 target**：Xcode → Runner → 右键 Runner → Add Files →
   勾选 `PrivacyInfo.xcprivacy`（Target 勾选 Runner）。*文件已在磁盘，但未注册进
   `project.pbxproj`，不加入则不会打进 IPA。*
3. **签名与能力**：Signing & Capabilities → 选择 Team；
   勾选 Background Modes（Location updates / Background fetch）；
   Apple Developer 后台为 App ID 开启 HealthKit、Location 能力。
4. **编译验证**：
   ```bash
   flutter pub get
   flutter build ios --release --no-codesign   # 先验证编译通过
   ```
5. **归档上传**：Xcode → Product → Archive → Distribute App →
   App Store Connect（上传前跑一次真机冒烟：首页定位、轨迹录制后台、步数读取）。
6. **App Store Connect 材料**：截图 6.7"/6.1"、描述、关键词、
   隐私「数据收集」问卷（按 `PrivacyInfo.xcprivacy` 勾选：精确位置/健身/照片，
   不关联身份、非追踪）、隐私政策 URL、分类与年龄分级。
7. **TestFlight 内测** → 提审。

## 3. 提审前自查（iOS 特别项）

- [ ] 后台定位用途说明在首次进入轨迹录制时前置弹窗解释（App 内已有授权说明弹框）
- [ ] HealthKit：只在用户主动进入步数页时请求授权（已按此实现）
- [ ] `PrivacyInfo.xcprivacy` 已随 IPA 打包（解压 IPA 校验存在）
- [ ] 账号注销入口可用（设置 → 注销账号）——Apple 5.1.1(v) 同样要求
