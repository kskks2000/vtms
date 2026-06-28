#!/usr/bin/env bash
# 가비아 컨테이너(파이썬) 호스팅에서 FastAPI 백엔드를 구동하는 스크립트.
# SSH 접속 후 backend 디렉터리에서 실행한다.
#
# 사용 전 확인:
#   - 가비아가 지정한 바인딩 포트를 GUNICORN_BIND 로 맞출 것
#     (예: export GUNICORN_BIND=0.0.0.0:8080)
#   - backend/.env 에 DATABASE_URL, SECRET_KEY 등 운영 값이 있을 것
set -euo pipefail

cd "$(dirname "$0")/.."

# 가상환경 준비 (최초 1회 생성, 이후 재사용)
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt

# 포그라운드 실행 (백그라운드 상시 실행은 아래 nohup 예시 참고)
exec gunicorn -c gunicorn_conf.py app.main:app

# 백그라운드 상시 실행이 필요하면 위 exec 줄 대신:
#   nohup gunicorn -c gunicorn_conf.py app.main:app > gunicorn.log 2>&1 &
