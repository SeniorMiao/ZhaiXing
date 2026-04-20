from enum import StrEnum


class MeetingStatus(StrEnum):
    created = "created"
    uploading = "uploading"
    queued = "queued"
    processing = "processing"
    ready = "ready"
    failed = "failed"
    deleted = "deleted"


class JobState(StrEnum):
    queued = "queued"
    running = "running"
    succeeded = "succeeded"
    failed = "failed"
    cancelled = "cancelled"


class JobStage(StrEnum):
    transcode = "transcode"
    asr = "asr"
    diarization = "diarization"
    align = "align"
    summarize = "summarize"
    assemble = "assemble"
    done = "done"

