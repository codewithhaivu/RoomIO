from pydantic_settings import BaseSettings
from sqlalchemy.ext.asyncio import AsyncSession ,async_sessionmaker
from sqlalchemy.ext.asyncio import create_async_engine

class Settings(BaseSettings):
    # Database
    DATABASE_URL :str
    DB_ECHO: bool

    # Redis
    REDIS_URL: str

    # JWT
    JWT_SECRET: str
    JWT_ALGORITHM: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int
    REFRESH_TOKEN_EXPIRE_DAYS: int

    #Cloudinary
    CLOUDINARY_CLOUD_NAME: str
    CLOUDINARY_API_KEY: str
    CLOUDINARY_API_SECRET: str

    #SMS TOKEN
    SMS_BASE_URL: str
    SMS_ACCESS_TOKEN: str
    class Config:
        env_file = ".env"
        case_sensitive = True # phân biệt hoa và thường

settings = Settings()
engine = create_async_engine(settings.DATABASE_URL,echo=settings.DB_ECHO)
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)



