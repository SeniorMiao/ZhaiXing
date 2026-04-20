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

见目录 `mobile/` 内说明：安装 Flutter 后执行 `cd mobile` → `flutter create .` → `flutter pub get` → `flutter run`（可用 `--dart-define=API_BASE_URL=...` 指向本机 API）。

### 一键启动（Windows）

在一个 PowerShell 里执行（会自动弹出两个窗口分别跑 API 与 Worker，并在当前窗口提示 `API_BASE_URL`）：

```powershell
cd D:\Code\Homework\ZhaiXing
powershell -ExecutionPolicy Bypass -File .\scripts\start-dev.ps1
```

