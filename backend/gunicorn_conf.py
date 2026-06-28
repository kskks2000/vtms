"""Gunicorn 설정 (FastAPI/ASGI 구동용).

FastAPI 는 ASGI 라 Gunicorn 의 Uvicorn 워커로 실행한다.
  gunicorn -c gunicorn_conf.py app.main:app

배포 환경(가비아 컨테이너 호스팅 등)에 맞춰 환경 변수로 조정한다.
  GUNICORN_BIND   : 바인딩 주소:포트 (가비아가 지정한 포트 규칙에 맞출 것)
  WEB_CONCURRENCY : 워커 수 (1GB 램이면 1~2 권장)
"""
import os

# 가비아 파이썬 호스팅은 8080 포트를 도메인에 연결한다.
bind = os.environ.get("GUNICORN_BIND", "0.0.0.0:8080")
workers = int(os.environ.get("WEB_CONCURRENCY", "2"))
worker_class = "uvicorn.workers.UvicornWorker"
timeout = 60
keepalive = 5
# 접근/에러 로그를 표준 출력으로 (백그라운드 실행 시 파일로 리다이렉트)
accesslog = "-"
errorlog = "-"
