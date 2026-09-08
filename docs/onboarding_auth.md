# 启动链路与鉴权体验优化说明

> 目标：补齐一个商业级客户端应具备的基础门控与登录体系——
> 启动加载页、首次引导页、生产级登录/注册页，并理顺启动路由与导航。
> 校验：`dart analyze lib` → **No issues found!**

---

## 一、新增页面

### 1. 启动加载页 `lib/pages/shared/splash_page.dart`（路由 `/splash`）
- 应用入口首屏，承接冷启动过渡：全屏品牌渐变 + Logo 弹性缩放进场 + 加载指示。
- 启动关键路径已在 `main.dart` 完成（存储初始化、会话恢复均早于 `runApp`），
  本页仅做 **1.5s 品牌展示**，不阻塞任何业务初始化。
- 路由决策（依据本地标记 `kGuideSeen`）：
  - 首次安装（未看引导）→ `/guide`
  - 已看引导 → `/home`

### 2. 首次引导页 `lib/pages/shared/guide_page.dart`（路由 `/guide`）
- `PageView` 四屏功能亮点：行前规划 / 轨迹记录 / AI 助手 / 云端同步。
- 底部指示点（选中态拉长动画）+ 「跳过」（右上角）+「下一步」/「立即体验」。
- 最后一屏额外提供 **「登录/注册，解锁云同步」** 入口（门控跳转）。
- 任一离开路径（跳过 / 立即体验 / 去登录）都会写入 `kGuideSeen=true`，
  保证引导页只在首次安装后展示一次。

### 3. 路由装配（`lib/router/app_router.dart`）
- `initialLocation` 由 `/home` 改为 **`/splash`**，形成启动门控。
- 新增 `/splash`、`/guide` 两条顶层全屏路由（位于 Tab 壳之前）。
- `/login` 改为接收路由 `extra`，用于区分「门控进入」与「从我页进入」。

---

## 二、登录/注册页重做 `lib/pages/profile/login_page.dart`

保留原有「登录/注册 Tab + 手机号密码 + 一键体验 + 本地/服务端双模式」逻辑，补全商业化体验：

| 能力 | 说明 |
| --- | --- |
| **门控跳转** | 通过 `extra: {'gated': true}` 标记。成功 / 跳过统一 `context.go('/home')`；从我页进入则 `context.pop()` 返回。彻底修复「401 拦截 push 登录后 pop 会退 App」的隐患。 |
| **隐私协议必勾选** | 新增《隐私政策》勾选框（可点击跳转 `/profile/privacy-policy`）。**登录、注册、一键体验** 在勾选前一律禁用，符合国内 App 合规要求。 |
| **游客跳过** | 门控场景下显示「暂不登录，先逛逛」，直接进入应用（维持本地演示可用性）。 |
| **统一关闭** | 右上角由「返回箭头」改为「关闭」，语义更贴合全屏门控。 |
| **按钮禁用态** | 未勾选协议或请求进行中时，提交/体验按钮呈现禁用态（`GradientButton` 已支持 `VoidCallback?`）。 |

> 设计说明：登录默认**不强制**——保持「本地演示模式」开箱即用的特性；
> 但账号体系（本地 JWT + 服务端 REST）已就绪，配置后端地址即切换真实接口，
> 商业闭环（收藏/轨迹云同步）可随时启用。

---

## 三、配套改动
- `lib/core/storage/app_storage.dart`：新增 `kGuideSeen` 存储键（引导只看一次）。
- `lib/pages/shared/widgets/common_widgets.dart`：`GradientButton.onPressed` 改为可空
  （`VoidCallback?`），按钮禁用态复用，不影响既有调用方。

---

## 四、启动与验收建议
- 用 **release / 真机** 验收：首次安装看引导 → 立即体验进首页；卸载重装或清 `travel_guideSeen` 后可再次触发引导。
- 登录页：未勾选协议时按钮禁用；勾选后可登录/注册/体验；门控进入时点「暂不登录」直接进首页。
- 服务端鉴权契约（`/auth/register`、`/auth/login`、`/auth/logout`）此前已与 `AuthService` 对齐，无需改动即可走通真实账号体系。
