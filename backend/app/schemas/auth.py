from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    nickname: str | None = Field(None, max_length=64)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserOut(BaseModel):
    id: int
    # 响应体不做 EmailStr 校验，避免库内历史脏数据导致登录已成功却序列化 500
    email: str | None
    nickname: str
    has_avatar: bool = False


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
