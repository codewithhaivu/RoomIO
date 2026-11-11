
from datetime import datetime, timezone, timedelta
import hashlib
from uuid import UUID

import jwt
from fastapi import HTTPException
from passlib.context import CryptContext
from core.config import settings
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto"
)
def verify_password(plain_password, hashed_password) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_token(data, token_type:str):
    exp =settings.REFRESH_TOKEN_EXPIRE_DAYS
    if token_type=="access_token":
        exp =settings.ACCESS_TOKEN_EXPIRE_MINUTES
        payload = {
            "sub": str(data),
            "type": token_type,
            "exp": datetime.now(timezone.utc) +  timedelta(minutes=exp)
        }
    else:
        payload = {
            "sub": str(data),
            "type": token_type,
            "exp": datetime.now(timezone.utc) +  timedelta(days=exp)
        }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)

def decode_token(token: str):
    return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])

def hash_token(token: str):
    return hashlib.sha256(token.encode()).hexdigest()

def verify_token(token: str):
    try:
        payload = decode_token(token)

        if payload.get("type") != "access_token":
            raise HTTPException(
                status_code=401,
                detail="Access token required"
            )

        user_id = payload.get("sub")

        if user_id is None:
            raise HTTPException(
                status_code=401,
                detail="Token does not contain user identifier"
            )

        return UUID(user_id)

    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=401,
            detail="Token đã hết hạn. Hãy dùng refresh token!"
        )

    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=401,
            detail="Token không hợp lệ hoặc bị làm giả!"
        )
