import json
import os
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from ..deps import get_current_user
from ...db.session import get_db
from ...models.enums import MeetingStatus
from ...models.job import Job
from ...models.meeting import MediaFile, Meeting, MeetingSummary
from ...models.transcript import TranscriptSegment
from ...models.user import User
from ...schemas.meeting import (
    MeetingCreateRequest,
    MeetingDetailResponse,
    MeetingListItem,
    MeetingSummaryResponse,
    MeetingTranscriptResponse,
    TranscriptSegmentOut,
)
from ...worker.tasks import process_meeting_job

router = APIRouter()

STORAGE_DIR = os.path.join(os.getcwd(), "storage")
os.makedirs(STORAGE_DIR, exist_ok=True)


def _meeting_for_user(db: Session, meeting_id: int, user: User) -> Meeting:
    m = db.query(Meeting).filter(Meeting.id == meeting_id, Meeting.user_id == user.id).one_or_none()
    if m is None:
        raise HTTPException(status_code=404, detail="meeting not found")
    return m


@router.post("", response_model=MeetingDetailResponse, status_code=status.HTTP_201_CREATED)
def create_meeting(
    payload: MeetingCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MeetingDetailResponse:
    meeting = Meeting(
        user_id=current_user.id,
        title=payload.title or "未命名会议",
        meeting_type=payload.meeting_type,
        status=MeetingStatus.created.value,
    )
    db.add(meeting)
    db.commit()
    db.refresh(meeting)
    return MeetingDetailResponse(
        id=meeting.id,
        title=meeting.title,
        meeting_type=meeting.meeting_type,
        status=meeting.status,
        created_at=meeting.created_at.isoformat(),
        updated_at=meeting.updated_at.isoformat(),
    )


@router.get("", response_model=list[MeetingListItem])
def list_meetings(
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[MeetingListItem]:
    rows = (
        db.query(Meeting)
        .filter(Meeting.user_id == current_user.id)
        .order_by(Meeting.created_at.desc())
        .limit(min(max(limit, 1), 100))
        .all()
    )
    return [
        MeetingListItem(
            id=m.id,
            title=m.title,
            meeting_type=m.meeting_type,
            status=m.status,
            created_at=m.created_at.isoformat(),
        )
        for m in rows
    ]


@router.get("/{meeting_id}", response_model=MeetingDetailResponse)
def get_meeting(
    meeting_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MeetingDetailResponse:
    m = _meeting_for_user(db, meeting_id, current_user)
    return MeetingDetailResponse(
        id=m.id,
        title=m.title,
        meeting_type=m.meeting_type,
        status=m.status,
        created_at=m.created_at.isoformat(),
        updated_at=m.updated_at.isoformat(),
    )


@router.post("/{meeting_id}/upload", response_model=MeetingDetailResponse)
def upload_meeting_media(
    meeting_id: int,
    file: UploadFile = File(...),
    chunk_index: int = Form(0),
    total_chunks: int = Form(1),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MeetingDetailResponse:
    m = _meeting_for_user(db, meeting_id, current_user)

    object_key = f"{meeting_id}/{uuid.uuid4().hex}-{file.filename}"
    dst_path = os.path.join(STORAGE_DIR, object_key.replace("/", "_"))
    with open(dst_path, "wb") as f:
        f.write(file.file.read())

    media = MediaFile(
        meeting_id=meeting_id,
        original_filename=file.filename or "upload",
        content_type=file.content_type,
        object_key=object_key,
        size_bytes=os.path.getsize(dst_path),
    )
    db.add(media)

    m.status = MeetingStatus.uploading.value if chunk_index + 1 < total_chunks else MeetingStatus.queued.value
    db.add(m)
    db.commit()
    db.refresh(m)

    return MeetingDetailResponse(
        id=m.id,
        title=m.title,
        meeting_type=m.meeting_type,
        status=m.status,
        created_at=m.created_at.isoformat(),
        updated_at=m.updated_at.isoformat(),
    )


@router.post("/{meeting_id}/process", status_code=status.HTTP_202_ACCEPTED)
def process_meeting(
    meeting_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict:
    m = _meeting_for_user(db, meeting_id, current_user)

    job = Job(meeting_id=meeting_id, state="queued", stage="transcode", progress=0)
    db.add(job)
    m.status = MeetingStatus.processing.value
    db.add(m)
    db.commit()
    db.refresh(job)

    process_meeting_job.delay(job.id)
    return {"job_id": job.id}


@router.get("/{meeting_id}/transcript", response_model=MeetingTranscriptResponse)
def get_transcript(
    meeting_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MeetingTranscriptResponse:
    _meeting_for_user(db, meeting_id, current_user)

    rows = (
        db.query(TranscriptSegment)
        .filter(TranscriptSegment.meeting_id == meeting_id)
        .order_by(TranscriptSegment.start_ms.asc(), TranscriptSegment.id.asc())
        .all()
    )
    return MeetingTranscriptResponse(
        meeting_id=meeting_id,
        segments=[
            TranscriptSegmentOut(
                id=s.id,
                start_ms=s.start_ms,
                end_ms=s.end_ms,
                speaker=s.speaker_label,
                text=s.text,
            )
            for s in rows
        ],
    )


@router.get("/{meeting_id}/summary", response_model=MeetingSummaryResponse)
def get_summary(
    meeting_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MeetingSummaryResponse:
    _meeting_for_user(db, meeting_id, current_user)

    row = db.query(MeetingSummary).filter(MeetingSummary.meeting_id == meeting_id).one_or_none()
    if row is None:
        return MeetingSummaryResponse(meeting_id=meeting_id, summary=None, todos=[], decisions=[], model_version=None)

    def _loads_list(v: str | None) -> list[str]:
        if not v:
            return []
        try:
            data = json.loads(v)
            return [str(x) for x in data] if isinstance(data, list) else []
        except Exception:
            return []

    return MeetingSummaryResponse(
        meeting_id=meeting_id,
        summary=row.summary_text,
        todos=_loads_list(row.todos_json),
        decisions=_loads_list(row.decisions_json),
        model_version=row.model_version,
    )

