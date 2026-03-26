# cos_work_app

合思协产 — 企业内部工作台（Flutter，内嵌业务 Web 页面）。

与 [cos-worker-app](../cos-worker-app)（Capacitor Android）为兄弟项目，共用同一后端 `https://cos.junhai.work`。

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
- Android SDK（minSdk 21）

## 运行

```bash
# 安装依赖
flutter pub get

# Android 真机/模拟器
flutter run
```

### 热重载 / 热重启（调试 UI 与 Dart 逻辑）

- 终端里 **`r`**：热重载（Hot Reload），改 Widget 样式/文案等可快速看到效果。
- **`R`**：热重启（Hot Restart），`initState`、全局单例（如 `CosAuthService`）初始化逻辑会变更时更可靠。
- **WebView 首跳脚本 / `MainActivity` Channel**：需 **`R` 或停止后重新 `flutter run`**；仅改 Portal 业务代码时仍要重新部署站点上的 `worker-portal.js`。

Worker Portal 小程序依赖壳在登录后写入的 **`wpt.` token**（`login_for_token`）；若仍进 Portal 登录页，确认站点已部署含 `worker_portal_api` 的 COS 版本，并在壳中重新登录一次。

## 无线调试（ADB）

手机与电脑需在同一局域网（或手机 USB 网络共享到电脑）。优先使用系统「无线调试」（Android 11+）。

### 方式 A：无线调试（推荐）

1. 手机：**开发者选项** → **无线调试** → 开启。
2. **配对**：点「使用配对码配对设备」，记下 **配对端口**（与调试端口不同）。在电脑上执行（将 `IP`、`配对端口` 换成手机界面上的值）：

   ```powershell
   cd c:\Users\weelc\Workspace\Coding\cos-work-app
   .\scripts\wireless-adb.ps1 pair -Endpoint 192.168.x.x:配对端口
   ```

   按提示输入 6 位配对码。

3. **连接**：回到无线调试主界面，记下 **IP 地址和端口**（调试端口，常见如 `5555` 或随机端口），执行：

   ```powershell
   .\scripts\wireless-adb.ps1 connect -Endpoint 192.168.x.x:调试端口
   .\scripts\wireless-adb.ps1 devices
   ```

4. **部署运行**：

   ```powershell
   flutter devices
   flutter run -d "192.168.x.x:调试端口"
   ```

   也可在项目根目录执行 `.\scripts\wireless-adb.ps1 run`（由 Flutter 自选设备；多设备时建议显式 `-d`）。

### 方式 B：USB 先开 TCP，再拔线

1. USB 连接手机，`adb devices` 能看到设备。
2. `.\scripts\wireless-adb.ps1 tcpip`（等价 `adb tcpip 5555`）。
3. 查看手机当前 Wi‑Fi IP，拔线后：`.\scripts\wireless-adb.ps1 connect -Endpoint 手机IP:5555`。

### 常见问题

- **找不到 adb**：安装 Android SDK Platform-Tools，或设置环境变量 `ANDROID_HOME`（脚本默认也会查 `%LOCALAPPDATA%\Android\sdk`）。
- **连接后掉线**：无线调试 IP 可能随 DHCP 变化，需重新 `connect`；部分机型休眠会断 adb。
- **多设备**：`flutter run -d <deviceId>` 与 `adb devices -l` 里第一列一致。

## 构建 APK

```bash
flutter build apk --debug
# 输出: build/app/outputs/flutter-apk/app-debug.apk
```

## 配置

- 入口 URL：`lib/main.dart` 中的 `kWorkerPortalUrl`（默认 `https://cos.junhai.work/worker-portal`）
- 应用 ID：`work.junhai.cos_work_app`

## 常见问题

**CMake / SDK 下载失败（TLS handshake）**：若网络无法访问 dl.google.com，需在 Android Studio → SDK Manager → SDK Tools 中勾选 CMake 并安装，或配置代理后重试。

**Maven 依赖慢**：已配置阿里云镜像（`android/build.gradle.kts`、`settings.gradle.kts`）。

## 后续演进

初期为 WebView 壳，后期可逐步将登录、审批、入库盘点等页面替换为原生 Flutter 实现。
