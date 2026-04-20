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

### 使用本地 Gradle zip（推荐，已写进工程）

`gradle-wrapper.properties` 使用 **`distributionUrl=gradle-8.14-all.zip`**（与 `gradle-wrapper.properties` **同目录**），**不再用 Java 下载 services.gradle.org**，可绕过 PKIX。

1. 将 `gradle-8.14-all.zip` 放到 **`mobile/android/gradle/wrapper/`**（与 `gradle-wrapper.properties` 同级）。  
2. 可用浏览器下载后复制；或在 `mobile/android` 下执行：`.\local-gradle\download_gradle.ps1`（内含 `curl --ssl-no-revoke`）。  
3. 再执行 `flutter run`。
