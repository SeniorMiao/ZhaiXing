from datetime import datetime, timedelta, timezone

import bcrypt
from jose import JWTError, jwt

from .settings import settings


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, password_hash: str | None) -> bool:
    if not password_hash:
        return False
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            password_hash.encode("utf-8"),
        )
    except (ValueError, TypeError):
        return False


def create_access_token(*, user_id: int) -> str:
    now = datetime.now(timezone.utc)
    exp = int((now + timedelta(minutes=settings.jwt_expire_minutes)).timestamp())
    payload = {"sub": str(user_id), "iat": int(now.timestamp()), "exp": exp}
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict | None:
    try:
        return jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except JWTError:
        return None
