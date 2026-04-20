from typing import Optional

from pydantic import BaseModel


class MeetingCreateRequest(BaseModel):
    title: Optional[str] = None
    meeting_type: str


class MeetingListItem(BaseModel):
    id: int
    title: str
    meeting_type: str
    status: str
    created_at: str


class MeetingDetailResponse(BaseModel):
    id: int
    title: str
    meeting_type: str
    status: str
    created_at: str
    updated_at: str


class TranscriptSegmentOut(BaseModel):
    id: int
    start_ms: int
    end_ms: int
    speaker: str
    text: str


class MeetingTranscriptResponse(BaseModel):
    meeting_id: int
    segments: list[TranscriptSegmentOut]


class MeetingSummaryResponse(BaseModel):
    meeting_id: int
    summary: Optional[str] = None
    todos: list[str] = []
    decisions: list[str] = []
    model_version: Optional[str] = None

