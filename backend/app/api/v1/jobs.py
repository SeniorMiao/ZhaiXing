from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..deps import get_current_user
from ...db.session import get_db
from ...models.job import Job
from ...models.meeting import Meeting
from ...models.user import User
from ...schemas.job import JobStatusResponse

router = APIRouter()


@router.get("", response_model=list[JobStatusResponse])
def list_jobs(
    meeting_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[JobStatusResponse]:
    m = db.query(Meeting).filter(Meeting.id == meeting_id, Meeting.user_id == current_user.id).one_or_none()
    if m is None:
        raise HTTPException(status_code=404, detail="meeting not found")
    rows = db.query(Job).filter(Job.meeting_id == meeting_id).order_by(Job.created_at.desc()).all()
    return [
        JobStatusResponse(
            id=j.id,
            meeting_id=j.meeting_id,
            stage=j.stage,
            state=j.state,
            progress=j.progress,
            error_message=j.error_message,
        )
        for j in rows
    ]


@router.get("/{job_id}", response_model=JobStatusResponse)
def get_job(
    job_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> JobStatusResponse:
    j = db.query(Job).filter(Job.id == job_id).one_or_none()
    if j is None:
        raise HTTPException(status_code=404, detail="job not found")
    m = db.query(Meeting).filter(Meeting.id == j.meeting_id, Meeting.user_id == current_user.id).one_or_none()
    if m is None:
        raise HTTPException(status_code=404, detail="job not found")
    return JobStatusResponse(
        id=j.id,
        meeting_id=j.meeting_id,
        stage=j.stage,
        state=j.state,
        progress=j.progress,
        error_message=j.error_message,
    )

