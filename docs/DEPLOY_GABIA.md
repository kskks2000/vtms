# 가비아 컨테이너 호스팅 배포 가이드 (FastAPI + Flutter 웹)

한 개의 가비아 컨테이너(파이썬) 호스팅에 **FastAPI 백엔드**를 올리고, 그
FastAPI 가 **Flutter 웹 빌드를 정적 파일로 함께 서빙**합니다. 프론트와 API 가
같은 도메인(`https://www.logistics.ai.kr`)이 되어 CORS 가 필요 없고, 앱은
`/api/...` 상대경로로 백엔드를 호출합니다.

```
브라우저 ─ https://www.logistics.ai.kr/        → FastAPI(StaticFiles) → Flutter 웹
        └ https://www.logistics.ai.kr/api/...  → FastAPI 라우터(API)
```

## 0. 배포 전 가비아에 확인 (1:1 문의)

FastAPI(ASGI)는 가비아 공식 안내(Django/Flask) 목록에 없으므로, 구매/배포 전에
아래를 확인하세요.

1. 컨테이너 파이썬 호스팅에서 **FastAPI 를 `gunicorn -k uvicorn.workers.UvicornWorker` 로 구동**할 수 있는가?
2. 애플리케이션이 **바인딩해야 하는 포트/주소 규칙**은? (이 값을 `GUNICORN_BIND` 에 넣습니다)
3. 컨테이너에서 **외부 DB(db.logistics.ai.kr:5432)로의 아웃바운드 접속**이 허용되는가? (기존 DB 를 계속 쓸 경우)
4. **백그라운드 상시 실행**(세션 종료 후에도 유지) 방법은? (nohup/매뉴얼 방식)

## 1. 서버 디렉터리 배치

SSH 로 접속해 홈 디렉터리에 아래처럼 둡니다(경로는 예시).

```
~/vtms/
├── backend/            # 이 저장소의 backend/ 를 업로드
│   ├── app/
│   ├── requirements.txt
│   ├── gunicorn_conf.py
│   ├── scripts/run_gabia.sh
│   ├── .env            # 서버에서 직접 작성 (업로드 금지)
│   └── .venv/          # 서버에서 생성 (업로드 금지)
└── web/                # 로컬 `flutter build web` 결과(build/web)의 내용
    ├── index.html
    ├── main.dart.js
    └── assets/ …
```

> `web/` 을 공개 웹 루트가 아니라 FastAPI 가 읽는 폴더로 둡니다. 백엔드가
> `FRONTEND_DIST` 경로의 파일을 서빙하므로, `.env`·소스가 공개 노출되지 않습니다.

## 2. 로컬에서 웹 빌드 (Mac)

```bash
cd /Users/robert/kcastle/claude/vtms
bash scripts/build_web.sh
```

`API_BASE_URL` 을 비워 빌드하므로 앱이 `/api/...` 상대경로로 호출합니다.
결과물은 `build/web/` 입니다.

## 3. 업로드

SFTP 또는 scp/rsync 로 올립니다(SSH 가능 시 rsync 권장).

```bash
# 백엔드 (가상환경/.env/.git 제외)
rsync -av --exclude '.venv' --exclude '.env' --exclude '__pycache__' \
  backend/  계정@호스트:~/vtms/backend/

# 프론트엔드 빌드 결과
rsync -av --delete build/web/  계정@호스트:~/vtms/web/
```

SFTP GUI(파일질라 등)만 된다면 같은 폴더 구조로 올리면 됩니다. `.env` 와
`.venv/` 는 올리지 마세요.

## 4. 서버 환경변수 (`~/vtms/backend/.env`)

SSH 로 접속해 작성합니다. 값은 실제에 맞게 바꾸세요.

```
DATABASE_URL=postgresql+psycopg2://사용자:비밀번호@db.logistics.ai.kr:5432/dblogis
DB_SCHEMA=vtms

# 운영용 랜덤 시크릿 (예: python3 -c "import secrets;print(secrets.token_urlsafe(48))")
SECRET_KEY=여기에-긴-랜덤-문자열
ACCESS_TOKEN_EXPIRE_MINUTES=480

# Flutter 웹 정적 서빙 경로 (절대경로)
FRONTEND_DIST=/home/계정명/vtms/web

# Firebase
FIREBASE_PROJECT_ID=vtms-e44bf
FIREBASE_GOOGLE_AUTO_PROVISION=true

# 같은 도메인이면 CORS 불필요. 분리 운영 대비 도메인만 적어둠.
BACKEND_CORS_ORIGINS=https://www.logistics.ai.kr
```

> DB 비밀번호에 특수문자가 있으면 URL 인코딩하세요(예: `!` → `%21`).

## 5. 의존성 설치 + 실행

```bash
cd ~/vtms/backend
# 가비아가 알려준 포트로 맞추세요 (예시: 8080)
export GUNICORN_BIND=0.0.0.0:8080
bash scripts/run_gabia.sh
```

`run_gabia.sh` 가 가상환경 생성 → `pip install -r requirements.txt` →
`gunicorn -c gunicorn_conf.py app.main:app` 까지 수행합니다.

### 백그라운드 상시 실행

세션을 닫아도 유지하려면(또는 가비아 매뉴얼의 백그라운드 방식 사용):

```bash
cd ~/vtms/backend
source .venv/bin/activate
nohup gunicorn -c gunicorn_conf.py app.main:app > gunicorn.log 2>&1 &
```

## 6. Firebase 콘솔 설정 (한 번만)

- Authentication > Sign-in method: **이메일/비밀번호**, **Google** 사용 설정
- Authentication > Settings > Authorized domains 에 **www.logistics.ai.kr**
  (및 사용하는 도메인) 추가 — 안 하면 Google 팝업이 `unauthorized-domain` 으로 실패

## 7. 동작 확인

- `https://www.logistics.ai.kr/health` → `{"status":"ok"}`
- `https://www.logistics.ai.kr/docs` → FastAPI 문서
- `https://www.logistics.ai.kr/` → 로그인 화면 표시, 로그인/회원가입 동작

## 트러블슈팅

| 증상 | 원인/조치 |
|------|-----------|
| 502 / 응답 없음 | gunicorn 미실행 또는 `GUNICORN_BIND` 포트가 가비아 규칙과 불일치 |
| 화면은 뜨는데 API 401/네트워크 오류 | `/api` 라우팅 확인, 백엔드 로그(`gunicorn.log`) 확인 |
| DB 연결 오류 | 외부 DB 아웃바운드 차단 또는 `DATABASE_URL`(특수문자 인코딩) 오류 |
| Google 로그인 실패 | Firebase Authorized domains 에 도메인 미등록, 또는 Google 제공업체 미사용 |
| 화면 빈 페이지 | `FRONTEND_DIST` 경로 오류(절대경로 확인), `index.html` 존재 확인 |

## DB 선택 (참고)

- **외부 DB 유지(권장 가능)**: 기존 `db.logistics.ai.kr` 의 `vtms` 스키마를 그대로
  사용. 컨테이너에서 5432 아웃바운드만 열려 있으면 됨.
- **호스팅 포함 PostgreSQL 사용**: 스탠더드 상품의 PostgreSQL(5GB)을 쓸 경우,
  **버전이 PostgreSQL 11 인지** 확인하고 스키마/시드를 옮겨야 함.
