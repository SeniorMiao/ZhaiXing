from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "dev"
    database_url: str
    redis_url: str

    hf_endpoint: str | None = None
    asr_model: str = "medium"
    hf_token: str | None = None

    zhipu_api_key: str | None = None
    zhipu_model: str = "glm-5.1"

    jwt_secret_key: str = Field(
        default="dev-only-change-me",
        description="JWT 签名密钥；生产环境务必通过环境变量覆盖",
    )
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7


settings = Settings()

