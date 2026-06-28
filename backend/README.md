# VTMS 백엔드 (FastAPI)

운송 관리 시스템 백엔드 API. 실제 `vtms` 스키마(PostgreSQL 11)에 연결되며, 이메일/비밀번호 + 구글 로그인을 지원합니다.

## 기술 스택

- FastAPI + Uvicorn
- SQLAlchemy 2.x (PostgreSQL 11, 스키마 `vtms`)
- JWT 인증 (python-jose), 비밀번호 해싱 (passlib/bcrypt)
- 구글 OAuth 검증 (google-auth)

## 실행 방법

```bash
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env        # 값 확인/수정 (DATABASE_URL, SECRET_KEY, GOOGLE_*)

uvicorn app.main:app --reload --port 8000
```

기동 시 기본 테넌트와 관리자 계정만 시드합니다. **테이블은 생성하지 않습니다** (이미 `vtms` 스키마에 존재).

- API 문서: http://localhost:8000/docs
- 헬스체크: http://localhost:8000/health

## DB 연결

`.env` 의 `DATABASE_URL` 로 접속하며 `DB_SCHEMA`(기본 `vtms`)를 search_path 로 고정합니다.
비밀번호에 특수문자가 있으면 URL 인코딩하세요 (예: `!` → `%21`).

테이블/데이터 점검:

```bash
python scripts/inspect_db.py
```

## 데모 계정

| 이메일 | 비밀번호 | 역할 |
|--------|----------|------|
| admin@vtms.com | admin1234 | admin (전체 권한) |

## 인증 API

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/api/auth/login` | 이메일/비밀번호 로그인, JWT 발급 |
| POST | `/api/auth/google` | 구글 ID 토큰으로 로그인, JWT 발급 |
| GET | `/api/auth/me` | 현재 사용자 정보 + roles/permissions (Bearer 필요) |

JWT 의 subject 는 `users.id` 입니다.

### 로그인 보안

- 비밀번호 `MAX_FAILED_LOGIN`(기본 5)회 실패 시 `LOCK_MINUTES`(기본 15분) 동안 계정 잠금.
- 성공 시 `last_login_at` 갱신, 실패 카운트 초기화.
- soft delete(`deleted_at`) 및 `is_active` 를 반영.

## 구글 로그인 설정

1. Google Cloud Console 에서 OAuth 클라이언트 ID 발급 (웹 + 안드로이드).
2. `.env` 설정:

```
GOOGLE_CLIENT_IDS=<웹클라이언트ID>,<안드로이드용 서버클라이언트ID>
GOOGLE_AUTO_PROVISION=false   # true 면 미등록 이메일도 자동 생성
```

3. 동작: 클라이언트가 받은 ID 토큰을 `/api/auth/google` 로 전송 → 서버가 서명/issuer/audience/이메일 검증 → 기존 사용자면 `external_auth_id` 연동, 없으면 (AUTO_PROVISION 시) 기본 테넌트로 생성 → JWT 발급.

## 스키마 매핑 메모

- `users`: `email`, `password_hash`, `full_name`, `tenant_id`, `is_active`, `failed_login_count`, `locked_until`, `external_auth_id` 등 실제 컬럼 사용. `id`/`public_id` 는 DB가 생성(IDENTITY/기본값).
- 역할/권한: `roles`(admin/dispatcher/csr/finance/viewer), `permissions`(10종), `role_permissions`, `user_roles` 조인.
- 운영에서는 Alembic 마이그레이션 도입 권장.
