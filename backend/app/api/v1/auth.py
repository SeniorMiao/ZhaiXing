import os

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from ..deps import get_current_user
from ...core.security import create_access_token, hash_password, verify_password
from ...db.session import get_db
from ...models.user import User
from ...schemas.auth import LoginRequest, RegisterRequest, TokenResponse, UserOut

router = APIRouter()

STORAGE_DIR = os.path.join(os.getcwd(), "storage")
_AVATAR_CT = {"image/jpeg", "image/png", "image/webp"}
_AVATAR_EXT = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def user_out(user: User) -> UserOut:
    return UserOut(
        id=user.id,
        email=user.email,
        nickname=user.nickname,
        has_avatar=bool(user.avatar_key and str(user.avatar_key).strip()),
    )


def _avatar_storage_path(fname: str) -> str:
    return os.path.join(STORAGE_DIR, fname)


def _avatar_media_type(fname: str) -> str:
    low = fname.lower()
    if low.endswith(".png"):
        return "image/png"
    if low.endswith(".webp"):
        return "image/webp"
    return "image/jpeg"


def _remove_old_avatars(user_id: int, keep_path: str | None) -> None:
    for ext in (".jpg", ".png", ".webp"):
        p = _avatar_storage_path(f"avatar_{user_id}{ext}")
        if os.path.isfile(p) and (keep_path is None or os.path.abspath(p) != os.path.abspath(keep_path)):
            try:
                os.remove(p)
            except OSError:
                pass


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = _normalize_email(str(payload.email))
    exists = db.query(User).filter(User.email == email).one_or_none()
    if exists is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="该邮箱已被注册")

    user = User(
        email=email,
        nickname=(payload.nickname.strip() if payload.nickname else None) or "用户",
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user_id=user.id)
    return TokenResponse(
        access_token=token,
        user=user_out(user),
    )


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = _normalize_email(str(payload.email))
    user = db.query(User).filter(User.email == email).one_or_none()
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="邮箱或密码错误")

    token = create_access_token(user_id=user.id)
    return TokenResponse(
        access_token=token,
        user=user_out(user),
    )


@router.get("/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user)) -> UserOut:
    return user_out(current_user)


@router.get("/avatar")
def get_my_avatar(current_user: User = Depends(get_current_user)) -> FileResponse:
    if not current_user.avatar_key:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="no avatar")
    path = _avatar_storage_path(current_user.avatar_key)
    if not os.path.isfile(path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="avatar file missing")
    return FileResponse(path, media_type=_avatar_media_type(current_user.avatar_key))


@router.post("/avatar", response_model=UserOut)
async def upload_my_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    raw_ct = (file.content_type or "").split(";")[0].strip().lower()
    if raw_ct not in _AVATAR_CT:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="仅支持 JPEG / PNG / WebP")
    data = await file.read()
    if len(data) > 2 * 1024 * 1024:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="图片不能超过 2MB")

    os.makedirs(STORAGE_DIR, exist_ok=True)
    ext = _AVATAR_EXT[raw_ct]
    fname = f"avatar_{current_user.id}{ext}"
    path = _avatar_storage_path(fname)
    _remove_old_avatars(current_user.id, keep_path=path)
    with open(path, "wb") as wf:
        wf.write(data)
    current_user.avatar_key = fname
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return user_out(current_user)


@router.delete("/avatar", response_model=UserOut)
def delete_my_avatar(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    if current_user.avatar_key:
        p = _avatar_storage_path(current_user.avatar_key)
        if os.path.isfile(p):
            try:
                os.remove(p)
            except OSError:
                pass
    current_user.avatar_key = None
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return user_out(current_user)
