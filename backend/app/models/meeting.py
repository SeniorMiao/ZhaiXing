from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..db.base import Base
from .enums import MeetingStatus


class Meeting(Base):
    __tablename__ = "meetings"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)

    title: Mapped[str] = mapped_column(String(255), default="未命名会议", nullable=False)
    meeting_type: Mapped[str] = mapped_column(String(32), nullable=False)
    status: Mapped[str] = mapped_column(String(32), default=MeetingStatus.created.value, index=True)

    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)
    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user = relationship("User", lazy="joined")
    media_files = relationship("MediaFile", back_populates="meeting")
    jobs = relationship("Job", back_populates="meeting")
    summary = relationship("MeetingSummary", back_populates="meeting", uselist=False)


class MediaFile(Base):
    __tablename__ = "media_files"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    meeting_id: Mapped[int] = mapped_column(ForeignKey("meetings.id"), index=True)

    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    content_type: Mapped[str | None] = mapped_column(String(128), nullable=True)
    object_key: Mapped[str] = mapped_column(String(512), nullable=False)
    size_bytes: Mapped[int | None] = mapped_column(nullable=True)

    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    meeting = relationship("Meeting", back_populates="media_files")


class MeetingSummary(Base):
    __tablename__ = "meeting_summaries"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    meeting_id: Mapped[int] = mapped_column(ForeignKey("meetings.id"), unique=True, index=True)

    summary_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    todos_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    decisions_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    model_version: Mapped[str | None] = mapped_column(String(64), nullable=True)

    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    meeting = relationship("Meeting", back_populates="summary")

