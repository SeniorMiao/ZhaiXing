# 智能会议纪要助手 · Flutter 客户端

## 环境

- 安装 [Flutter](https://docs.flutter.dev/get-started/install)（稳定版，并配置好 `flutter` / `dart` 在 PATH）。
- 本仓库的 `mobile/` 目录**仅包含** `lib/`、`pubspec.yaml` 等；首次请在项目根目录执行：

```bash
cd mobile
flutter create .
flutter pub get
```

`flutter create .` 会根据已有 `pubspec.yaml` 生成 `android/`、`ios/` 等平台工程，**不会覆盖**你的 `lib/`。

## 配置后端地址

默认连接 `http://127.0.0.1:8000`。可按环境覆盖：

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.8:8000
```

- **真机**：请使用电脑的**局域网 IP**，且 PC 上启动 API 时使用 `uvicorn main:app --host 0.0.0.0 --port 8000`。
- **Android 模拟器**访问本机：`http://10.0.2.2:8000`。

## Android Studio 运行（模拟器）

1. **File → Open** 选本目录 `mobile`（不要打开上一级 `ZhaiXing`）。
2. 安装插件：**Flutter** + **Dart**（Settings → Plugins），并配置 Flutter SDK：`D:\01_Dev\Environment\FlutterSDK`（安装脚本见仓库 `scripts\install-flutter.ps1`）。
3. 等待索引结束，终端执行 `flutter pub get`。
4. 运行配置（任选一种）：
   - 顶部下拉应出现 **`ZhaiXing (Android Emulator)`**（见 `.idea/runConfigurations/`，已带 `10.0.2.2:8000`）。选模拟器后点 Run。
   - 或 **Run → Edit Configurations → + → Flutter**（若没有 Flutter 项，说明插件未装好）：
     - Dart entrypoint: `lib/main.dart`
     - Additional run args: `--dart-define=API_BASE_URL=http://10.0.2.2:8000`
   - 或在左侧 **`lib/main.dart` 右键 → Run 'main.dart'**，再在配置里补上 Additional run args。
5. PC 上先执行 `D:\03_Projects\Homework\ZhaiXing\start-dev.cmd` 启动 API + Worker。

命令行（不依赖 Android Studio 配置）：

```powershell
cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Android 明文 HTTP（调试用）

若使用 `http://` 而非 `https`，生成 `android` 后请在 `android/app/src/main/AndroidManifest.xml` 的 `<application>` 上增加：

`android:usesCleartextTraffic="true"`（仅建议开发环境）。

## 功能

- 注册 / 登录（JWT 存 `flutter_secure_storage`）
- 会议列表、新建会议
- 选择音频上传、`开始处理`、轮询任务进度
- 转写 / 纪要 Tab 展示

请同时在本机运行 **Celery Worker**，否则任务会一直排队。

## Gradle 构建报 SSLHandshakeException / PKIX

多为 **Gradle 下载发行版 zip** 时，当前 **JDK 不信任** 对端证书（公司代理、杀毒 HTTPS 扫描、系统时间错误等）。

1. **Android Studio → Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK**：选 **Android Studio 自带的 jbr**（不要用过旧或来历不明的 JDK）。
2. 在 `android/gradle.properties` 里配置 **`org.gradle.java.home`** 指向同一 **jbr** 目录（路径见下节注释示例），保存后再执行 `flutter run`。
3. 暂时关闭杀软的 **HTTPS 解密/扫描**，或换 **手机热点** 排除公司中间人证书。
4. 确认 Windows **日期、时间、时区** 正确。

仍失败时：用浏览器打开  
https://services.gradle.org/distributions/gradle-8.14-all.zip  
若浏览器能下、命令行不能，基本可确定是 **Java 信任库/所用 JDK** 问题，优先完成步骤 1～2。

### Kotlin 编译报 `different roots` / Daemon compilation failed

项目在 **D:** 盘而 Pub Cache 默认在 **C:** 盘时，Kotlin 增量编译会失败。已在本仓库 `android/gradle.properties` 中设置 `kotlin.incremental=false`。

建议将 Pub Cache 也放到 D 盘（与 `scripts/env-paths.ps1` 一致）：

```powershell
# 用户环境变量（需重开终端 / Android Studio）
PUB_CACHE=D:\01_Dev\Environment\PubCache
```

然后：

```powershell
cd mobile
flutter clean
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### Android NDK / SDK 许可未接受

```powershell
powershell -ExecutionPolicy Bypass -File ..\scripts\accept-android-licenses.ps1
```

或在 Android Studio：**Settings → Languages & Frameworks → Android SDK → SDK Tools**，勾选 **NDK** 与 **Android SDK Command-line Tools** 后 Apply。

### 找不到 `gradle-8.14-all.zip`（FileNotFoundException）

默认已改为 **腾讯云镜像** 在线下载（`gradle-wrapper.properties`），一般**不需要**手动放 zip。直接再执行：

```powershell
cd mobile
flutter clean
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

若仍报 **PKIX / SSL**，再改用**本地 zip**（与 `gradle-wrapper.properties` 同目录）：

1. 将 `gradle-wrapper.properties` 里 `distributionUrl` 改回：`gradle-8.14-all.zip`
2. 下载完整包（约 214MB）到 `mobile/android/gradle/wrapper/`：  
   执行 `.\android\local-gradle\download_gradle.ps1`，或浏览器打开  
   https://mirrors.cloud.tencent.com/gradle/gradle-8.14-all.zip  
3. 确认文件约 **200MB+**（不完整的小文件会再次报错），再 `flutter run`
