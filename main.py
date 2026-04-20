from fastapi import FastAPI

# 根目录 main.py 仅作为启动入口：
# `uvicorn main:app --reload`
try:
    from backend.app.main import app  # type: ignore
except Exception as e:
    app = FastAPI()

    @app.get("/")
    async def placeholder_root():
        return {"message": "backend not ready", "error": repr(e)}