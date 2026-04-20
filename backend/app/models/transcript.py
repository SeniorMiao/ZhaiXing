from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from ..db.base import Base


class TranscriptSegment(Base):
    __tablename__ = "transcript_segments"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    meeting_id: Mapped[int] = mapped_column(ForeignKey("meetings.id"), index=True)

    start_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    end_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    speaker_label: Mapped[str] = mapped_column(String(64), default="Speaker A", nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)

    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

