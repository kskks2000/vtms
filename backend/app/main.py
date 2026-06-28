import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api import auth
from app.core.config import settings
from app.db.session import SessionLocal
from app.masters.router import router as master_router
from app.orders.router import router as order_router
from app.seed import seed_admin


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 테이블은 이미 vtms 스키마에 존재하므로 생성하지 않는다.
    # 개발 편의를 위해 기본 테넌트/관리자만 시드한다.
    db = SessionLocal()
    try:
        seed_admin(db)
    finally:
        db.close()
    yield


app = FastAPI(title=settings.PROJECT_NAME, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix=settings.API_PREFIX)
app.include_router(master_router, prefix=settings.API_PREFIX)
app.include_router(order_router, prefix=settings.API_PREFIX)


@app.get("/health", tags=["system"])
def health():
    return {"status": "ok"}


# 프론트엔드(Flutter 웹) 정적 서빙.
# FRONTEND_DIST 가 설정되고 경로가 존재할 때만 마운트한다.
# 반드시 API/health/docs 라우트 등록 이후 마지막에 마운트해야 "/" 캐치올이
# 다른 라우트를 가리지 않는다. (해시 라우팅이라 SPA 폴백은 불필요)
if settings.FRONTEND_DIST and os.path.isdir(settings.FRONTEND_DIST):
    app.mount(
        "/",
        StaticFiles(directory=settings.FRONTEND_DIST, html=True),
        name="frontend",
    )
