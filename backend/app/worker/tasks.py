import json
import shutil
import subprocess

from sqlalchemy.orm import Session

from ..core.settings import settings
from ..db.session import SessionLocal
from ..models.enums import JobStage, JobState, MeetingStatus
from ..models.job import Job
from ..models.meeting import MediaFile, Meeting, MeetingSummary
from ..models.transcript import TranscriptSegment
from ..services.asr import release_asr_model, transcribe_with_faster_whisper
from ..services.diarization import assign_speaker_labels, diarize_audio
from ..services.media import object_key_to_local_path
from ..services.summarize import summarize_fallback, summarize_with_zhipu
from .celery_app import celery_app


def _update_job(db: Session, job: Job, *, stage: str, progress: int, state: str | None = None) -> None:
    job.stage = stage
    job.progress = progress
    if state is not None:
        job.state = state
    db.add(job)
    db.commit()


@celery_app.task(name="process_meeting_job")
def process_meeting_job(job_id: int) -> None:
    db = SessionLocal()
    try:
        job = db.query(Job).filter(Job.id == job_id).one()
        meeting = db.query(Meeting).filter(Meeting.id == job.meeting_id).one()

        job.state = JobState.running.value
        db.add(job)
        db.commit()

        media = (
            db.query(MediaFile)
            .filter(MediaFile.meeting_id == meeting.id)
            .order_by(MediaFile.created_at.desc(), MediaFile.id.desc())
            .first()
        )
        if media is None:
            raise RuntimeError("meeting has no uploaded media_file yet")

        src_path = object_key_to_local_path(media.object_key)

        ffmpeg_exe = shutil.which("ffmpeg")
        if not ffmpeg_exe:
            import imageio_ffmpeg  # type: ignore

            ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()

        _update_job(db, job, stage=JobStage.transcode.value, progress=10)
        wav_path = src_path + ".wav"
        subprocess.run(
            [ffmpeg_exe, "-y", "-i", src_path, "-ac", "1", "-ar", "16000", wav_path],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        _update_job(db, job, stage=JobStage.asr.value, progress=35)
        asr_segments = transcribe_with_faster_whisper(
            wav_path,
            settings.asr_model,
            settings.hf_endpoint,
            language=settings.asr_language,
            initial_prompt=settings.asr_initial_prompt,
            chunk_seconds=settings.asr_chunk_seconds,
        )
        release_asr_model()

        speaker_labels: list[str]
        if settings.diarization_enabled:
            _update_job(db, job, stage=JobStage.diarization.value, progress=55)
            diar_segments = diarize_audio(
                wav_path,
                model_cache_dir=settings.diarization_model_cache,
                speaker_num=settings.diarization_speaker_num,
            )
            speaker_labels = assign_speaker_labels(asr_segments, diar_segments)
        else:
            speaker_labels = ["Speaker A"] * len(asr_segments)

        _update_job(db, job, stage=JobStage.align.value, progress=70)
        db.query(TranscriptSegment).filter(TranscriptSegment.meeting_id == meeting.id).delete()
        db.add_all(
            [
                TranscriptSegment(
                    meeting_id=meeting.id,
                    start_ms=s.start_ms,
                    end_ms=s.end_ms,
                    speaker_label=spk,
                    text=s.text,
                )
                for s, spk in zip(asr_segments, speaker_labels)
            ]
        )
        db.commit()

        _update_job(db, job, stage=JobStage.summarize.value, progress=90)
        full_text = "\n".join([f"{spk}: {s.text}" for s, spk in zip(asr_segments, speaker_labels)])
        if settings.zhipu_api_key:
            sum_res = summarize_with_zhipu(full_text=full_text, api_key=settings.zhipu_api_key, model=settings.zhipu_model)
        else:
            sum_res = summarize_fallback(full_text)

        _update_job(db, job, stage=JobStage.assemble.value, progress=95)
        summary = db.query(MeetingSummary).filter(MeetingSummary.meeting_id == meeting.id).one_or_none()
        if summary is None:
            summary = MeetingSummary(meeting_id=meeting.id)
        summary.summary_text = sum_res.summary
        summary.todos_json = json.dumps(sum_res.todos, ensure_ascii=False)
        summary.decisions_json = json.dumps(sum_res.decisions, ensure_ascii=False)
        summary.model_version = sum_res.model_version
        db.add(summary)
        db.commit()

        meeting.status = MeetingStatus.ready.value
        db.add(meeting)
        db.commit()

        _update_job(db, job, stage=JobStage.done.value, progress=100, state=JobState.succeeded.value)

    except Exception as e:
        try:
            job = db.query(Job).filter(Job.id == job_id).one_or_none()
            if job is not None:
                job.state = JobState.failed.value
                job.error_message = str(e)
                db.add(job)
                db.commit()
        finally:
            raise
    finally:
        db.close()

