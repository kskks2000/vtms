from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """환경 변수 기반 설정. .env 파일에서 로드한다."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    PROJECT_NAME: str = "VTMS API"
    API_PREFIX: str = "/api"

    DATABASE_URL: str = "postgresql+psycopg2://logis:logis@localhost:5432/dblogis"
    DB_SCHEMA: str = "vtms"

    SECRET_KEY: str = "change-this-to-a-long-random-secret"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480

    # 로그인 보안 정책
    MAX_FAILED_LOGIN: int = 5
    LOCK_MINUTES: int = 15

    BACKEND_CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8080"

    # Flutter 웹 빌드(build/web) 경로. 설정되면 FastAPI 가 같은 도메인에서
    # 프론트엔드 정적 파일을 함께 서빙한다(배포 시 사용, 개발 시 비워둠).
    FRONTEND_DIST: str = ""

    # 구글 OAuth
    GOOGLE_CLIENT_IDS: str = ""
    GOOGLE_AUTO_PROVISION: bool = False

    # Firebase Authentication
    # 프로젝트 ID (Firebase 콘솔 > 프로젝트 설정). ID 토큰의 audience/issuer 검증에 사용.
    FIREBASE_PROJECT_ID: str = "vtms-e44bf"
    # 미등록 이메일/비밀번호 계정으로 로그인 시 자동 계정 생성 여부.
    FIREBASE_AUTO_PROVISION: bool = False
    # 미등록 Google 계정으로 로그인 시 자동 계정 생성 여부.
    # Google 은 이메일 인증이 보장되므로 기본 허용한다.
    FIREBASE_GOOGLE_AUTO_PROVISION: bool = True

    # 기본 테넌트 / 시드
    DEFAULT_TENANT_CODE: str = "DEFAULT"
    DEFAULT_TENANT_NAME: str = "기본 테넌트"
    SEED_USER_EMAIL: str = "admin@vtms.com"
    SEED_USER_PASSWORD: str = "admin1234"
    SEED_USER_NAME: str = "관리자"

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.BACKEND_CORS_ORIGINS.split(",") if o.strip()]

    @property
    def google_client_ids(self) -> list[str]:
        return [c.strip() for c in self.GOOGLE_CLIENT_IDS.split(",") if c.strip()]


settings = Settings()
