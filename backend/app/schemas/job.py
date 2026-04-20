from pydantic import BaseModel


class JobStatusResponse(BaseModel):
    id: int
    meeting_id: int
    stage: str
    state: str
    progress: int
    error_message: str | None = None

