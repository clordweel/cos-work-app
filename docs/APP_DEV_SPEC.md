# Cos Work App 开发规范

本文档约定 **Flutter Android 壳应用**（`cos_work_app`）的架构边界、命名、与 COS 后端协作方式。细节命令与签名步骤见仓库根目录 [`README.md`](../README.md)。

---

## 1. 范围与目标

| 项 | 约定 |
|----|------|
| 平台 | **仅维护 Android**；`windows` / `web` / `macos` 已移除；`ios/` 保留结构但非现阶段目标。 |
| 定位 | 企业内工作台：**登录 / 站点配置 / 小程序启动器 / WebView 内嵌业务**（Worker Portal、Frappe Desk 等）。 |
| 演进 | 初期以 WebView 为主；新功能优先在清晰边界内扩展，避免与全局单例、Cookie 生命周期打架。 |

---

## 2. 目录与分层

```
lib/
  main.dart                 # 入口、SystemChrome、启动顺序（SiteStore → LoginHistory → AuthService）
  cos_theme.dart            # Material 主题与 CosShellTokens 挂载
  config/                   # 站点、品牌、Frappe 方法名常量（与 vendor/cos 对齐）
  auth/                     # 登录、会话、Cookie、生物识别、Worker Portal token
  mini_program/             # 小程序模型、注册表、Portal hash 引导
  routing/                  # 命名路由、小程序注册
  screens/                  # 各全屏页面
  ui/                       # ThemeExtension（壳 token）、断点等
  wechat_ui/                # 仿微信顶栏、胶囊（仅小程序运行页等使用）
```

**原则**

- **业务编排**放在 `screens/` + 少量 `routing/`，**不要**在 `main.dart` 堆逻辑。
- **与站点通信**统一经 `CosAuthService`、`CosSiteStore` 及 `config/cos_frappe_api_methods.dart` 中的方法路径，避免散落字符串。
- **WebView 专用逻辑**（User-Agent、注入脚本、Cookie 范围）集中在 `auth/cos_web_auth_scope.dart` 与 `screens/mini_program_runner_screen.dart`。

---

## 3. 命名与代码风格

- 语言：**中文注释**；对外可见文案与用户可见字符串用产品用语（与现有屏一致）。
- Dart：`flutter_lints` / `analysis_options.yaml`；`dart format` 提交前可跑一遍。
- 文件：小写蛇形 `cos_auth_service.dart`；类型名大驼峰。
- 禁止：把 **API Key / keystore 密码** 写入仓库；`android/key.properties`、`*.jks` 仅本地或 CI 密钥库。

---

## 4. 配置与默认站点

- **默认站点根**：`lib/config/cos_site_config.dart`，支持 `--dart-define=COS_SITE_ORIGIN=...`；未传时默认生产类域名（以代码为准）。
- **运行时站点**：`CosSiteStore` 持久化用户选择的 origin，与登录态、请求基址一致。
- 修改默认站点或编译开关时，同步检查：**登录 API**、**WebView 首跳 URL**、**文档说明**。

---

## 5. 认证与会话

- **单一入口**：`CosAuthService`（登录、登出、bootstrap、Worker Portal token、与原生会话协作）。
- **Frappe 方法名字符串**：只从 `CosFrappeApiMethods` 引用，后端改名须**同时**改 `vendor/cos` 与客户端常量，并更新注释中的文件指向。
- **Worker Portal**：Bearer `wpt.` 由服务端 `login_for_token` / `issue_token_from_session` 发放；壳侧负责存储与刷新策略，详见 `README` 与 `worker_portal_token_bootstrap.dart`。
- **生物识别**：仅作解锁门禁，不替代服务端鉴权；状态由 `CosAuthService.needsBiometricUnlock` 等与 `MaterialApp` 的 `key` 联动，避免栈上残留错误页面。

---

## 6. WebView 与小程序

### 6.1 小程序模型

- `CosMiniProgram`：`launchPath`、`authKind`（`frappeSession` / `workerPortalToken`）、服务端拉取的图标与启用状态等。
- **注册**：`mini_program_registry.dart` + 服务端 `get_launcher_programs` / `get_market_programs` 配置，避免硬编码生产路径。

### 6.2 User-Agent 约定

- WebView 须带 **`CosWorkApp`** 片段，供 H5（如 Worker Portal `clientEnv.isCosFlutterShell()`）识别嵌入壳并调整布局。
- 修改 UA 时同步 **H5 检测逻辑** 与相关文档。

### 6.3 顶栏与 H5 安全区

- 壳顶栏高度与 **`WeChatMiniProgramNavBar.barHeight`**（44）对齐；沉浸式叠在 WebView 上。
- **Android WebView** 往往无可靠 `env(safe-area-inset-top)`：由 Flutter 在页面生命周期内向 `document.documentElement` 注入 CSS 变量（如 `--cos-status-bar-height`、`--cos-nav-bar-height`），H5 使用 `calc(var(...) + var(...))` 做 `padding-top`。新增壳内页面时勿假设仅靠 CSS `safe-area` 即可。

### 6.4 加载与错误

- 加载态、错误条、重试（刷新 / 重新进入）行为以 `mini_program_runner_screen.dart` 为准；改动时保持与 Cookie 预灌、`NavigationDelegate` 一致。

---

## 7. UI 与主题

- **全局主题**：`buildCosWorkTheme()` + `CosShellTokens`（`ThemeExtension`），小程序相关屏通过 `context.cosShell` 取色与间距。
- **仿微信组件**：`wechat_ui/` 与产品视觉一致即可，避免引入与壳风格冲突的第三方整页主题。
- **无障碍**：关键按钮、登录等路径保留 `Semantics` 等（以现有屏为参考）。

---

## 8. 路由

- 根导航由 `AppRoutes` / `main.dart` 中 `MaterialApp` 的 `routes` 或 `home` 组合管理；登录态变化通过 **`key` 重建** 清栈时，新增路由须评估是否会被误清。

---

## 9. 构建与签名

- **Release**：使用团队 keystore + `android/key.properties`（自 `key.properties.example` 复制）；脚本见 `scripts/build_android_release.ps1`。
- **applicationId**：`work.junhai.cos_work_app`（与 `android/app/build.gradle.kts` 一致），变更需评估推送与升级策略。

---

## 10. 测试与提交前检查

```powershell
.\scripts\verify.ps1
```

等价于 `flutter analyze` + `flutter test`。合并前至少执行一次；修改 `auth/`、`mini_program_runner_screen`、Cookie 路径时建议真机验证登录与小程序首跳。

---

## 11. 与仓库外协作

| 依赖 | 说明 |
|------|------|
| `vendor/cos`（ai_cos_ops 工作区） | 白名单 API、Worker Portal 静态资源构建、部署流程与生产站点一致时再发版。 |
| Worker Portal 前端 | 壳内 UA、CSS 变量、`localStorage` 键名变更须双端同步。 |

---

## 12. 修订记录

| 日期 | 摘要 |
|------|------|
| 2026-03-28 | 首版：目录分层、API 常量、WebView/H5 安全区、构建与协作约定。 |
