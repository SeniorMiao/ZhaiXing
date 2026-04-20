from sqlalchemy import inspect, text

from backend.app.db.base import Base
from backend.app.db.session import engine

# 导入 models 以注册 metadata
from backend.app import models  # noqa: F401


def _ensure_users_avatar_key() -> None:
    inspector = inspect(engine)
    if not inspector.has_table("users"):
        return
    columns = {c["name"] for c in inspector.get_columns("users")}
    if "avatar_key" in columns:
        return
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE users ADD COLUMN avatar_key VARCHAR(512) NULL"))
    print("OK: added column users.avatar_key (existing database migration).")


def _ensure_users_password_hash() -> None:
    inspector = inspect(engine)
    if not inspector.has_table("users"):
        return
    columns = {c["name"] for c in inspector.get_columns("users")}
    if "password_hash" in columns:
        return
    with engine.begin() as conn:
        conn.execute(text("ALTER TABLE users ADD COLUMN password_hash VARCHAR(255) NULL"))
    print("OK: added column users.password_hash (existing database migration).")


def ensure_schema() -> None:
    """幂等：创建缺失表，并为已有库补齐迁移列（避免 ORM 查询报 500）。"""
    Base.metadata.create_all(bind=engine)
    _ensure_users_password_hash()
    _ensure_users_avatar_key()


def main() -> None:
    ensure_schema()
    print("OK: tables created/verified.")


if __name__ == "__main__":
    main()

