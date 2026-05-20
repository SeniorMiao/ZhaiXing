from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "dev"
    database_url: str
    redis_url: str

    hf_endpoint: str | None = None
    asr_model: str = "medium"
    # auto=自动检测；zh/en 等=强制语言（英文会议勿设 zh）
    asr_language: str = "auto"
    asr_initial_prompt: str | None = None
    # 长音频按段转写（秒），避免 VAD 一次性分配过大矩阵 OOM
    asr_chunk_seconds: int = 300
    hf_token: str | None = None

    # 3D-Speaker CAM++ 说话人分离（ModelScope 模型缓存目录，可选）
    diarization_enabled: bool = True
    diarization_model_cache: str | None = None
    diarization_speaker_num: int | None = None

    zhipu_api_key: str | None = None
    zhipu_model: str = "glm-5.1"

    jwt_secret_key: str = Field(
        default="dev-only-change-me",
        description="JWT 签名密钥；生产环境务必通过环境变量覆盖",
    )
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7


settings = Settings()

