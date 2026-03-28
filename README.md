# cos_work_app

合思协产 — 企业内部工作台（**Flutter Android**；内嵌业务 WebView）。

与 [cos-worker-app](../cos-worker-app)（Capacitor Android）为兄弟项目，默认对接同一类 COS 站点（如 `https://cos.junhai.work`）。

## 平台范围

- **当前仅维护 Android**：仓库已移除 `windows/`、`web/`、`macos/` 工程目录；开发以真机或模拟器为主。
- `ios/` 仍保留为 Flutter 默认结构，**非现阶段目标**，未做联调承诺。

## 开发环境配置（Scoop）

本机已安装 [Scoop](https://scoop.sh) 时，执行：

```powershell
cd c:\Users\weelc\Workspace\Coding\cos-work-app
.\scripts\setup-env.ps1
```

脚本将安装：git、openjdk17、flutter、android-sdk。Flutter 约 1.7GB，下载需数分钟。完成后执行 `flutter doctor --android-licenses` 接受协议，再运行 `.\scripts\run.ps1` 启动应用。

若 Scoop 安装 Flutter 失败（如文件被占用），可手动安装：

```powershell
# 下载并解压到 C:\flutter
Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.41.4-stable.zip" -OutFile "$env:TEMP\flutter.zip" -UseBasicParsing
Expand-Archive -Path "$env:TEMP\flutter.zip" -DestinationPath "C:\" -Force
# 将 C:\flutter\bin 加入 PATH
$env:Path += ";C:\flutter\bin"
```

## 前置条件

- Flutter SDK 3.24+
- Android SDK（随 Flutter 指引安装）

## 运行

```bash
flutter pub get
flutter run    # Android 真机/模拟器
```

### 编译期默认站点（可选）

默认站点根地址来自 `lib/config/cos_site_config.dart` 的 `String.fromEnvironment('COS_SITE_ORIGIN')`，未传入时默认为 `https://cos.junhai.work`。自定义示例：

```bash
flutter run --dart-define=COS_SITE_ORIGIN=https://cos-dev.example.com
```

用户仍可在 App 内「设置」修改站点，并持久化到本机。

### 热重载 / 热重启

- 终端 **`r`**：热重载。
- **`R`**：热重启（`initState`、全局单例变更时更可靠）。
- **WebView 首跳 / MainActivity MethodChannel**：需 **`R` 或重新 `flutter run`**。

Worker Portal 类小程序依赖壳在登录后写入的 **`wpt.` token**（`login_for_token`）；若仍进 Portal 登录页，确认站点已部署对应 COS 版本，并在壳中重新登录一次。

## 提交前自检与 CI

```powershell
.\scripts\verify.ps1
```

等价于 `flutter analyze` + `flutter test`。GitHub Actions 工作流：`.github/workflows/flutter_ci.yml`（分析、测试、Linux 上构建 **debug APK** 作回归；**不包含** 正式签名）。

## 构建发布包（Android）

1. 复制 `android/key.properties.example` 为 `android/key.properties`，填写 keystore（`key.properties`、`.jks` 已列入 `.gitignore`）。
2. 将 keystore 文件放在 `android/` 下（或按 `storeFile` 填写路径）。
3. 执行：

```powershell
.\scripts\build_android_release.ps1              # APK
.\scripts\build_android_release.ps1 -AppBundle   # Google Play 用 AAB
```

若无 `key.properties`，release 构建仍会使用 **debug 签名**（仅本地调试，不可用于上架）。

## 无线调试（ADB）

手机与电脑需在同一局域网（或手机 USB 网络共享到电脑）。优先使用系统「无线调试」（Android 11+）。

### 方式 A：无线调试（推荐）

1. 手机：**开发者选项** → **无线调试** → 开启。
2. **配对**：点「使用配对码配对设备」，记下 **配对端口**。在电脑上执行（将 `IP`、`配对端口` 换成手机界面上的值）：

   ```powershell
   cd c:\Users\weelc\Workspace\Coding\cos-work-app
   .\scripts\wireless-adb.ps1 pair -Endpoint 192.168.x.x:配对端口
   ```

   按提示输入 6 位配对码。

3. **连接**：回到无线调试主界面，记下 **IP 地址和端口**（调试端口），执行：

   ```powershell
   .\scripts\wireless-adb.ps1 connect -Endpoint 192.168.x.x:调试端口
   .\scripts\wireless-adb.ps1 devices
   ```

4. **部署运行**：

   ```powershell
   flutter devices
   flutter run -d "192.168.x.x:调试端口"
   ```

### 方式 B：USB 先开 TCP，再拔线

1. USB 连接手机，`adb devices` 能看到设备。
2. `.\scripts\wireless-adb.ps1 tcpip`（等价 `adb tcpip 5555`）。
3. 查看手机当前 Wi‑Fi IP，拔线后：`.\scripts\wireless-adb.ps1 connect -Endpoint 手机IP:5555`。

### 常见问题

- **找不到 adb**：安装 Android SDK Platform-Tools，或设置 `ANDROID_HOME`（脚本默认也会查 `%LOCALAPPDATA%\Android\sdk`）。
- **连接后掉线**：无线调试 IP 可能随 DHCP 变化，需重新 `connect`；部分机型休眠会断 adb。
- **多设备**：`flutter run -d <deviceId>` 与 `adb devices -l` 里第一列一致。

## 后端接口约定（摘要）

Frappe 方法名字符串集中在 `lib/config/cos_frappe_api_methods.dart`，应与 `vendor/cos` 中 `work_app_launcher_api`、`company_context_api`、`worker_portal_api` 等实现同步。

## 应用标识

- `applicationId` / `namespace`：`work.junhai.cos_work_app`

## 常见问题

**CMake / SDK 下载失败（TLS handshake）**：若网络无法访问 dl.google.com，需在 Android Studio → SDK Manager → SDK Tools 中勾选 CMake 并安装，或配置代理后重试。

**Maven 依赖慢**：已配置阿里云镜像（`android/build.gradle.kts`、`settings.gradle.kts`）。

## 后续演进

初期为 WebView 壳，后期可逐步将登录、审批、入库盘点等页面替换为原生 Flutter 实现。
