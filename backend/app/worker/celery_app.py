from celery import Celery

from ..core.settings import settings

celery_app = Celery("zx_meeting_assistant", broker=settings.redis_url, backend=settings.redis_url)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="Asia/Shanghai",
    enable_utc=False,
)

