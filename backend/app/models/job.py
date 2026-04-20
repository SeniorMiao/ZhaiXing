from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..db.base import Base
from .enums import JobStage, JobState


class Job(Base):
    __tablename__ = "jobs"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    meeting_id: Mapped[int] = mapped_column(ForeignKey("meetings.id"), index=True)

    state: Mapped[str] = mapped_column(String(32), default=JobState.queued.value, index=True)
    stage: Mapped[str] = mapped_column(String(32), default=JobStage.transcode.value)
    progress: Mapped[int] = mapped_column(Integer, default=0)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    meeting = relationship("Meeting", back_populates="jobs")

