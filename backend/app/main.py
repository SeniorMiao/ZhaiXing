from contextlib import asynccontextmanager

from fastapi import FastAPI

from .api.v1 import auth, jobs, meetings


@asynccontextmanager
async def _lifespan(app: FastAPI):
    from .scripts.init_db import ensure_schema

    ensure_schema()
    yield


def create_app() -> FastAPI:
    app = FastAPI(title="智能会议纪要助手 API", version="0.4.0", lifespan=_lifespan)

    app.include_router(auth.router, prefix="/v1/auth", tags=["auth"])
    app.include_router(meetings.router, prefix="/v1/meetings", tags=["meetings"])
    app.include_router(jobs.router, prefix="/v1/jobs", tags=["jobs"])

    @app.get("/health", tags=["system"])
    async def health():
        return {"status": "ok"}

    return app


app = create_app()

