from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from core.firebase import init_firebase


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Khởi tạo Firebase khi Backend startup
    init_firebase()
    print("Firebase initialized successfully")

    yield

    # Chạy khi Backend shutdown (nếu cần cleanup)


app = FastAPI(lifespan=lifespan)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)
