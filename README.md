## 智能会议纪要助手（MVP：上传→ASR→摘要(智谱 GLM-5.1)）

### 启动依赖（MySQL/Redis）

```bash
docker compose up -d
```

### 安装依赖（虚拟环境 ZX）

```bash
.\ZX\Scripts\python -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### 初始化建表

```bash
.\ZX\Scripts\python -m backend.app.scripts.init_db
```

若你的库在加入「登录注册」之前已经建过表：直接再执行一次上面的 `init_db`，会自动检测并补上 `users.password_hash` 列。

也可手动执行（等价）：

```sql
ALTER TABLE users ADD COLUMN password_hash VARCHAR(255) NULL;
```

（脚本文件：`backend/app/scripts/add_password_hash_mysql.sql`）

### MySQL 账号（与本项目 `.env` 对齐）

如果你还没创建 `zx/zxpass` 用户，请用 `root` 登录 MySQL 后执行：

```sql
CREATE DATABASE IF NOT EXISTS meeting_assistant DEFAULT CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS 'zx'@'localhost' IDENTIFIED BY 'zxpass';
GRANT ALL PRIVILEGES ON meeting_assistant.* TO 'zx'@'localhost';
FLUSH PRIVILEGES;
```

> 如果你不想用 `zx` 用户，也可以修改 `.env` 的 `DATABASE_URL` 为你自己的账号密码。

### 启动 API

```bash
.\ZX\Scripts\python -m uvicorn main:app --reload --port 8000
```

### 启动 Worker（另开一个终端）

```bash
.\ZX\Scripts\python -m celery -A backend.app.worker.celery_app worker -l info -P solo
```

### 关键接口

**认证（无需 Bearer）**

- `POST /v1/auth/register` 注册（邮箱 + 密码，可选昵称），返回 `access_token` 与用户信息
- `POST /v1/auth/login` 登录

**认证后（请求头 `Authorization: Bearer <access_token>`）**

- `GET /v1/auth/me` 当前用户
- `POST /v1/meetings` 创建会议
- `GET /v1/meetings` 当前用户的会议列表
- `POST /v1/meetings/{id}/upload` 上传音频
- `POST /v1/meetings/{id}/process` 触发异步处理
- `GET /v1/jobs?meeting_id=` 某会议下的任务列表
- `GET /v1/jobs/{job_id}` 查询进度
- `GET /v1/meetings/{id}/transcript` 转写结果
- `GET /v1/meetings/{id}/summary` 摘要/待办/决策

`.env` 可配置 `JWT_SECRET_KEY`（默认仅适合本地开发）。

### 说话人分离（3D-Speaker CAM++）

无需 HuggingFace 账号，模型从 **ModelScope（魔搭）** 下载。首次处理会下载 CAM++ 声纹模型（约 27MB）。

**安装（项目根目录，一次性）：**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install-3dspeaker.ps1
.\ZX\Scripts\python.exe -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

`.env` 可选：

| 变量 | 说明 |
|------|------|
| `DIARIZATION_ENABLED` | `true`（默认）/ `false` 关闭说话人分离 |
| `DIARIZATION_MODEL_CACHE` | ModelScope 缓存目录（可选） |
| `DIARIZATION_SPEAKER_NUM` | 已知说话人数时可指定，如 `2` |

处理流程：`转码 → ASR → diarization（CAM++）→ 按时间戳对齐说话人 → 摘要`。

修改依赖或 `.env` 后请 **重启 Celery Worker**。

**若长音频 ASR 报 `Unable to allocate ... MiB`：**

- 已默认每 **5 分钟** 切一段转写（`ASR_CHUNK_SECONDS=300`），内存仍不够可改为 `180`
- 同时保持 `ASR_MODEL=base` 或 `tiny`，并只保留一个 Celery Worker

**若转写只有一两句、与音频长度不符：**

- 检查是否 **英文/中文混用**：此前强制 `language=zh` 会导致英文会议几乎无法识别；现已默认 `ASR_LANGUAGE=auto`
- 英文会议可在 `.env` 设 `ASR_LANGUAGE=en`，中文设 `zh`
- 改完后重启 Worker 并 **重新处理** 音频

**若 ASR 报 `mkl_malloc: failed to allocate memory`：**

1. `.env` 改用较小模型：`ASR_MODEL=base` 或 `tiny`（不要用 `medium`/`large` 除非内存 ≥16GB）
2. 关闭多余 Celery / API 窗口，只保留 **一个** Worker
3. 用 `start-dev.cmd` 重启（已限制 MKL/OMP 单线程以降低峰值内存）

**若纪要显示 `fallback-v1/v2` 或内容像转写摘录：**

未配置 `ZHIPU_API_KEY` 时只会做**本地摘录**，不是 AI 归纳。到 [智谱开放平台](https://open.bigmodel.cn/) 申请 Key 后写入 `.env` 并重启 Worker，摘要将变为结构化纪要（摘要 / 待办 / 决策）。

### 测试用户（本地联调）

脚本 `backend/app/scripts/reset_test_user.py` 会**清空与会议相关的数据并重建一个测试账号**，便于反复登录、移动端联调。

在项目根目录执行：

```bash
.\ZX\Scripts\python -m backend.app.scripts.reset_test_user
```

| 字段 | 值 |
| --- | --- |
| 邮箱 | `test@example.com` |
| 密码 | `test123456` |
| 昵称 | `测试用户` |

> 执行后会议、转写、任务等会被清空，仅保留上述测试用户；请勿在生产环境使用。

### Flutter 移动端

见目录 [`mobile/`](mobile/) 内说明；**完整 Windows 裸机部署**见 [`docs/DEPLOY-WINDOWS.md`](docs/DEPLOY-WINDOWS.md)（含 Android Studio 模拟器与踩坑附录）。

### 一键启动（Windows）

在一个 PowerShell 里执行（会自动弹出两个窗口分别跑 API 与 Worker，并在当前窗口提示 `API_BASE_URL`）。

**无需先 `cd` 到固定盘符路径**（脚本按自身位置解析项目根目录）。例如在 `mobile/` 子目录里也可以：

```powershell
powershell -ExecutionPolicy Bypass -File "D:\03_Projects\Homework\ZhaiXing\start-dev.ps1"
```

或在项目根目录（任选其一）：

```powershell
cd D:\03_Projects\Homework\ZhaiXing
.\start-dev.cmd
```

```powershell
cd D:\03_Projects\Homework\ZhaiXing
powershell -ExecutionPolicy Bypass -File .\start-dev.ps1
```

> 若直接执行 `.\start-dev.ps1` 报「禁止运行脚本」，是 PowerShell 执行策略限制，请用上面的 `start-dev.cmd` 或带 `-ExecutionPolicy Bypass` 的命令。

