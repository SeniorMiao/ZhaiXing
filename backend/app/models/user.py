from sqlalchemy import DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from ..db.base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, index=True, nullable=True)
    phone: Mapped[str | None] = mapped_column(String(32), unique=True, index=True, nullable=True)
    nickname: Mapped[str] = mapped_column(String(64), default="用户", nullable=False)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # 头像文件位于项目 storage 目录，仅存文件名（如 avatar_1.jpg）
    avatar_key: Mapped[str | None] = mapped_column(String(512), nullable=True)

    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

