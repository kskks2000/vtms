from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.core.config import settings

# 모든 테이블이 vtms 스키마에 있으므로 search_path 를 고정한다.
# 이렇게 하면 모델에서 스키마를 명시하지 않아도 vtms 가 우선 조회된다.
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    connect_args={"options": f"-csearch_path={settings.DB_SCHEMA},public"},
)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


def get_db():
    """요청 단위 DB 세션 의존성."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
