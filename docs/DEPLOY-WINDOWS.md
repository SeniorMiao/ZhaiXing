# ZhaiXing 智能会议纪要助手 · Windows 裸机部署指南

本文档面向 **Windows 10/11 裸机**，从零安装依赖到 **后端 API + Celery + MySQL + Redis + Flutter Android 模拟器** 完整联调。  
示例路径以本机实际部署为准，可按你的磁盘修改。

| 用途 | 示例路径 |
|------|----------|
| 项目源码 | `D:\03_Projects\Homework\ZhaiXing` |
| 统一环境目录 | `D:\01_Dev\Environment` |
| Python 虚拟环境 | `D:\03_Projects\Homework\ZhaiXing\ZX`（项目内） |
| Flutter SDK | `D:\01_Dev\Environment\FlutterSDK` |
| MySQL / Redis | `D:\01_Dev\Environment\mysql`、`...\Redis` |

---

## 0. 架构一览

```
┌─────────────────┐     HTTP      ┌──────────────────┐
│ Flutter 客户端   │ ────────────► │ FastAPI :8000    │
│ (Android 模拟器) │  10.0.2.2     └────────┬─────────┘
└─────────────────┘                        │
                                           ▼
                                  ┌──────────────────┐
                                  │ Celery Worker     │
                                  │ 转码→ASR→分离→摘要 │
                                  └────────┬─────────┘
                                           │
                        ┌──────────────────┼──────────────────┐
                        ▼                  ▼                  ▼
                   MySQL 3306         Redis 6379         storage/
                   meeting_assistant   任务队列           音频文件
```

**处理流水线：** 上传音频 → ffmpeg 转 16k wav → faster-whisper 转写 → 3D-Speaker CAM++ 说话人分离 → 智谱 GLM 生成纪要。

---

## 1. 前置准备（裸机必装）

### 1.1 系统与权限

- Windows 10/11 64 位，**建议 16GB 内存**（ASR + 说话人分离较吃内存；8GB 可用 `ASR_MODEL=tiny`）
- 管理员权限（安装软件、写环境变量）
- 可访问外网或国内镜像（清华 PyPI、魔搭 ModelScope、Flutter 国内镜像）

### 1.2 必装软件

| 软件 | 用途 | 建议 |
|------|------|------|
| [Git](https://git-scm.com) | 克隆 Flutter / 3D-Speaker | 安装时选「Git 来自 PATH」 |
| [Python 3.11+](https://www.python.org/) | 后端（**勿用 3.14 跑 FunASR**；3.11～3.12 最稳） | 勾选 **Add to PATH** |
| [Android Studio](https://developer.android.com/studio) | 模拟器 + SDK + Gradle | 自带 JDK（JBR） |
| 7-Zip 或 WinRAR | 解压 MySQL/Redis 压缩包 | 可选 |

> **说明：** 本项目脚本默认 **不用 Docker**，MySQL/Redis 为本机 zip 安装。若你已熟悉 Docker，也可自行 `docker compose up -d`，并改 `.env` 中连接串。

### 1.3 可选：统一环境目录

编辑 `scripts\env-paths.ps1` 中的 `$DevEnvRoot`，改为你希望存放 MySQL/Redis/Flutter 的目录（默认 `D:\01_Dev\Environment`）。

---

## 2. 获取源码

```powershell
cd D:\03_Projects\Homework
git clone https://github.com/SeniorMiao/ZhaiXing.git
cd ZhaiXing
```

若已有源码，确保路径无中文空格问题即可。

---

## 3. 安装 MySQL + Redis

### 3.1 一键脚本（推荐）

在 **PowerShell** 中（项目根目录）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup-deps.ps1
```

脚本会：

1. 若不存在则安装 Redis（tporadowski Windows 版）到 `%DevEnvRoot%\Redis`
2. 若不存在则安装 MySQL zip 到 `%DevEnvRoot%\mysql`
3. 启动 Redis、MySQL，并初始化账号/库

### 3.2 手动确认 MySQL 账号

默认与 `.env.example` 一致：

```sql
CREATE DATABASE IF NOT EXISTS meeting_assistant DEFAULT CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS 'zx'@'localhost' IDENTIFIED BY 'zxpass';
GRANT ALL PRIVILEGES ON meeting_assistant.* TO 'zx'@'localhost';
FLUSH PRIVILEGES;
```

### 3.3 验证

```powershell
redis-cli -h 127.0.0.1 ping
# 期望：PONG

# MySQL 登录（路径以本机为准）
& "D:\01_Dev\Environment\mysql\...\bin\mysql.exe" -uzx -pzxpass -e "SHOW DATABASES;"
```

也可单独启动：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\start-redis.ps1
powershell -ExecutionPolicy Bypass -File scripts\start-mysql.ps1
```

---

## 4. Python 后端环境

### 4.1 创建虚拟环境

```powershell
cd D:\03_Projects\Homework\ZhaiXing
python -m venv ZX
.\ZX\Scripts\Activate.ps1
```

若 `Activate.ps1` 被策略禁止，用：

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### 4.2 安装依赖

```powershell
.\ZX\Scripts\python.exe -m pip install -U pip
.\ZX\Scripts\python.exe -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

**PyTorch（CPU 版，说话人分离需要）：**

```powershell
.\ZX\Scripts\python.exe -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
```

### 4.3 安装 3D-Speaker（说话人分离，一次性）

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-3dspeaker.ps1
```

会克隆 `third_party/3D-Speaker` 并安装 ModelScope 等依赖。首次处理会议时从 **魔搭** 下载 CAM++ 模型（约 27MB）。

### 4.4 配置 `.env`

```powershell
copy .env.example .env
notepad .env
```

**开发推荐配置：**

```ini
DATABASE_URL=mysql+pymysql://zx:zxpass@127.0.0.1:3306/meeting_assistant?charset=utf8mb4
REDIS_URL=redis://127.0.0.1:6379/0

HF_ENDPOINT=https://hf-mirror.com

ASR_MODEL=base
ASR_LANGUAGE=auto
ASR_CHUNK_SECONDS=300

ZHIPU_API_KEY=你的智谱Key
ZHIPU_MODEL=glm-4-flash

DIARIZATION_ENABLED=true
```

| 变量 | 说明 |
|------|------|
| `ASR_MODEL` | `tiny`/`base` 省内存；`medium` 需 16GB+ RAM |
| `ASR_LANGUAGE` | `auto` 自动中英；纯英文设 `en`，纯中文设 `zh` |
| `ASR_CHUNK_SECONDS` | 长音频分段转写，默认 300 秒 |
| `ZHIPU_API_KEY` | 空则纪要仅为本地摘录，非 AI 归纳 |
| `DIARIZATION_ENABLED` | `false` 可关闭说话人分离以省内存 |

### 4.5 初始化数据库

```powershell
.\ZX\Scripts\python.exe -m backend.app.scripts.init_db
.\ZX\Scripts\python.exe -m backend.app.scripts.reset_test_user
```

测试账号：

| 字段 | 值 |
|------|-----|
| 邮箱 | `test@example.com` |
| 密码 | `test123456` |

### 4.6 接受 Android SDK 许可（后续 Flutter 构建需要）

```powershell
powershell -ExecutionPolicy Bypass -File scripts\accept-android-licenses.ps1
```

---

## 5. 启动后端

### 5.1 一键启动（推荐）

```powershell
cd D:\03_Projects\Homework\ZhaiXing
.\start-dev.cmd
```

会弹出 **两个窗口**：

- **API**：`uvicorn main:app --host 0.0.0.0 --port 8000`
- **Celery Worker**：`celery ... worker -P solo`

> 务必只保留 **一组** API + Worker；多开会占双倍内存导致 ASR OOM。

### 5.2 验证 API

浏览器打开：http://127.0.0.1:8000/docs  

或 PowerShell：

```powershell
(Invoke-WebRequest http://127.0.0.1:8000/docs -UseBasicParsing).StatusCode
# 期望：200
```

---

## 6. Flutter 与 Android Studio

### 6.1 安装 Flutter SDK

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-flutter.ps1
```

脚本会：

- 克隆 Flutter 到 `%DevEnvRoot%\FlutterSDK`（清华 git 镜像）
- 设置用户环境变量：`PUB_HOSTED_URL`、`FLUTTER_STORAGE_BASE_URL`、`PUB_CACHE`
- 首次执行 `flutter --version` 下载 Dart 缓存

**关闭并重新打开** 终端 / Android Studio 使 PATH 生效。

验证：

```powershell
flutter doctor -v
```

常见警告（cmdline-tools、licenses）不必然阻塞模拟器运行。

### 6.2 安装 Android Studio

1. 安装 [Android Studio](https://developer.android.com/studio)
2. 首次启动：**SDK Components** 勾选 Android SDK、Platform、**Android Emulator**
3. **Settings → Plugins**：安装 **Flutter**、**Dart**
4. **Settings → Languages & Frameworks → Flutter**：SDK path 填  
   `D:\01_Dev\Environment\FlutterSDK`
5. **Settings → Build → Gradle → Gradle JDK**：选 **Embedded JDK (JBR)**

### 6.3 创建 Android 模拟器

1. **Tools → Device Manager → Create Device**
2. 选 **Pixel** 系列 + **x86_64** 系统镜像（建议 API 34+）
3. 启动模拟器，确认能进桌面

### 6.4 打开 Flutter 工程

**重要：** File → Open 选 **`ZhaiXing\mobile`**，不要打开上级 `ZhaiXing`。

```powershell
cd D:\03_Projects\Homework\ZhaiXing\mobile
flutter pub get
```

> 本仓库 **已包含** `android/` 目录，**不要** 再执行 `flutter create .`（会覆盖配置）。

### 6.5 配置 API 地址

| 运行目标 | API_BASE_URL |
|----------|----------------|
| Android 模拟器 | `http://10.0.2.2:8000` |
| 真机（同一 WiFi） | `http://<电脑局域网IP>:8000` |
| 本机 Windows 桌面 | `http://127.0.0.1:8000` |

命令行运行：

```powershell
cd D:\03_Projects\Homework\ZhaiXing\mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Android Studio 可使用 `.idea/runConfigurations/ZhaiXing_Emulator.xml`（已带上述参数）。

### 6.6 首次构建 Android

首次会下载 Gradle、NDK 等，耗时较长。`gradle-wrapper.properties` 已指向腾讯云镜像。

建议（可选）设置用户环境变量，避免 Kotlin 跨盘编译问题：

```
PUB_CACHE=D:\01_Dev\Environment\PubCache
JAVA_HOME=D:\01_Dev\Environment\Java21
```

`JAVA_HOME` 指向 JDK **根目录**，不要带 `\bin`。

---

## 7. 端到端联调

1. 启动 MySQL、Redis（若未运行）：`setup-deps.ps1` 或单独 start 脚本  
2. 启动后端：`.\start-dev.cmd`  
3. 启动 Android 模拟器  
4. 运行 Flutter：`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`  
5. App 登录 `test@example.com` / `test123456`  
6. 新建会议 → 上传音频 → 等待处理（进度条）→ 查看 **转写 / 纪要** Tab  

**注意：**

- Celery Worker 必须运行，否则任务一直排队  
- 首次 ASR 会下载 Whisper 模型（走 `HF_ENDPOINT` 镜像）  
- 首次说话人分离会下载 CAM++（魔搭）  
- 处理时间与音频长度、CPU 性能、模型大小成正比  

---

## 8. 日常开发命令速查

```powershell
# 后端
cd D:\03_Projects\Homework\ZhaiXing
.\start-dev.cmd

# 重置测试数据
.\ZX\Scripts\python.exe -m backend.app.scripts.reset_test_user

# 移动端
cd mobile
flutter clean
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

---

## 附录 A · 本次部署踩坑与解决方案

以下为本项目 **实际 Windows 部署** 中遇到的问题汇总。

### A.1 路径与启动

| 现象 | 原因 | 解决 |
|------|------|------|
| README 旧路径 `D:\Code\Homework\ZhaiXing` 启动失败 | 文档路径过时 | 以实际克隆路径为准；用 `start-dev.cmd` 自动解析项目根 |
| `.\start-dev.ps1` 报「禁止运行脚本」 | PowerShell 执行策略 | 用 `.\start-dev.cmd` 或 `-ExecutionPolicy Bypass` |

### A.2 Gradle / Android 构建

| 现象 | 原因 | 解决 |
|------|------|------|
| `org.gradle.java.home ... invalid` 指向 `D:/Codebuilders/AndroidStudio/jbr` | `gradle.properties` 硬编码他人路径 | 删除该行；`JAVA_HOME` 指向本机 JDK 根目录 |
| `gradle-8.14-all.zip` FileNotFoundException | 官方源 SSL/网络 | 已改腾讯云镜像；完整 zip 约 **200MB+** |
| Kotlin `different roots`（C: Pub Cache vs D: 项目） | 跨盘符增量编译 | `kotlin.incremental=false`；`PUB_CACHE` 放 D 盘 |
| NDK / SDK `LicenceNotAcceptedException` | 未接受许可 | `scripts\accept-android-licenses.ps1` 或 SDK Manager |
| Gradle zip 下载不完整（~110MB） | curl 中断 | 浏览器或镜像重新下载，确认 **200MB+** |

### A.3 后端 / ASR / 内存

| 现象 | 原因 | 解决 |
|------|------|------|
| `mkl_malloc: failed to allocate memory` @ asr | `ASR_MODEL=medium` + 多 Worker 占内存 | 改 `base`/`tiny`；只保留一个 Celery Worker；`start-dev.ps1` 限制 OMP 单线程 |
| `Unable to allocate 836 MiB ... shape (1, 273813, 400)` | 长音频 VAD 一次性分配巨大矩阵 | `ASR_CHUNK_SECONDS=300` 分段转写 |
| 长音频只有 2 句转写 | 英文音频却 `language=zh` | `ASR_LANGUAGE=auto` 或 `en` |
| Whisper 首次极慢 / 卡在 35% | 下载 medium 模型 ~1.5GB | 正常；改用 `base` 或预下载；国内用 `HF_ENDPOINT` |

### A.4 纪要 / 智谱

| 现象 | 原因 | 解决 |
|------|------|------|
| 模型显示 `fallback-v1`，纪要像两句转写 | 未配 `ZHIPU_API_KEY`；旧 fallback 只取前两行 | 配置智谱 Key；已升级 fallback-v2 |
| `summarize · failed`：`No module named 'sniffio'` | 智谱 SDK 依赖缺失 | `pip install sniffio`（已写入 requirements.txt） |
| 英文会议摘要变中文乱归纳 | 摘要 prompt 固定中文 | 已按转写语言自动切换中/英 prompt |

### A.5 说话人分离

| 现象 | 原因 | 解决 |
|------|------|------|
| 全是 `Speaker A` | 未实现 / 未启用 | 运行 `install-3dspeaker.ps1`；`DIARIZATION_ENABLED=true` |
| HuggingFace 429 / 超时 | 国内网络 / 代理 IP 被限流 | pyannote 方案放弃；改用 **CAM++ + ModelScope**，无需 HF 账号 |
| FunASR VAD 在 Python 3.14 失败 | 依赖不兼容 | 自研能量 VAD +  spectral 聚类，不依赖 FunASR |

### A.6 Flutter / 环境

| 现象 | 原因 | 解决 |
|------|------|------|
| `flutter` 找不到 | 未装 SDK / PATH 未刷新 | `install-flutter.ps1` 后重开终端 |
| Flutter SDK incomplete | 未跑过 `flutter --version` | 首次执行下载 `bin/cache` |
| symlink 警告 | Windows 未开开发者模式 | 设置 → 开发者选项 → **开发人员模式** |
| `install-3dspeaker.ps1` 引号解析错误 | 中文弯引号 | 已改为英文单引号字符串 |

---

## 附录 B · 推荐 `.env` 按机器内存

| 内存 | ASR_MODEL | DIARIZATION | 备注 |
|------|-----------|-------------|------|
| 8GB | `tiny` | `false` | 先跑通链路 |
| 16GB | `base` | `true` | **推荐开发配置** |
| 32GB+ | `small` / `medium` | `true` | 可缩短 `ASR_CHUNK_SECONDS` |

---

## 附录 C · 仍无法解决时收集的信息

1. `flutter doctor -v` 完整输出  
2. Celery Worker 窗口 **完整报错**（从 `Task ...` 起）  
3. `.env` 中 `ASR_MODEL`、`ASR_LANGUAGE`、`DIARIZATION_ENABLED`（**勿贴 API Key**）  
4. 音频时长、语言（中/英）、文件大小  
5. 任务管理器中 `python.exe` 数量与内存占用  

---

## 附录 D · 相关文件索引

| 文件 | 作用 |
|------|------|
| `start-dev.cmd` | 一键启动 API + Worker |
| `scripts/env-paths.ps1` | 统一 DevEnv 路径 |
| `scripts/setup-deps.ps1` | MySQL + Redis 安装启动 |
| `scripts/install-flutter.ps1` | Flutter SDK + 镜像 |
| `scripts/install-3dspeaker.ps1` | 说话人分离依赖 |
| `scripts/accept-android-licenses.ps1` | SDK 许可 |
| `backend/app/services/asr.py` | 转写（分段、语言） |
| `backend/app/services/diarization.py` | CAM++ 说话人分离 |
| `backend/app/services/summarize.py` | 智谱 / fallback 纪要 |
| `mobile/README.md` | 移动端补充说明 |

---

*文档版本：2026-05，与当前仓库 `main` 部署实践一致。*
