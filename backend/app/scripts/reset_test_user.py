from sqlalchemy.orm import Session

from backend.app.core.security import hash_password
from backend.app.db.session import SessionLocal
from backend.app.models.job import Job
from backend.app.models.meeting import MediaFile, Meeting, MeetingSummary
from backend.app.models.transcript import TranscriptSegment
from backend.app.models.user import User


def reset_all_data_and_create_test_user(
    db: Session,
    *,
    email: str,
    password: str,
    nickname: str = "Test",
) -> User:
    # 先删依赖表，避免外键约束失败
    db.query(TranscriptSegment).delete()
    db.query(Job).delete()
    db.query(MeetingSummary).delete()
    db.query(MediaFile).delete()
    db.query(Meeting).delete()
    db.query(User).delete()
    db.commit()

    user = User(
        email=email.strip().lower(),
        nickname=nickname,
        password_hash=hash_password(password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def main() -> None:
    email = "test@example.com"
    password = "test123456"
    nickname = "测试用户"

    db = SessionLocal()
    try:
        user = reset_all_data_and_create_test_user(
            db,
            email=email,
            password=password,
            nickname=nickname,
        )
        print("OK: reset users and related data.")
        print(f"Test user id={user.id} email={email} password={password}")
    finally:
        db.close()


if __name__ == "__main__":
    main()

