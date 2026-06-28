#!/usr/bin/env python3
"""가비아 서버용: 기존 gunicorn 전부 종료 후 8080으로 1개만 재기동.

사용(서버에서):  python3 scripts/restart_gabia.py
"""
import glob
import os
import signal
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.dirname(HERE)


def kill_existing_gunicorn():
    me = os.getpid()
    killed = []
    for d in glob.glob("/proc/[0-9]*"):
        try:
            cmd = (
                open(os.path.join(d, "cmdline"), "rb")
                .read()
                .decode("utf-8", "ignore")
                .replace("\x00", " ")
            )
        except Exception:
            continue
        try:
            pid = int(os.path.basename(d))
        except ValueError:
            continue
        if "gunicorn" in cmd and pid != me:
            try:
                os.kill(pid, signal.SIGTERM)
                killed.append(pid)
            except Exception:
                pass
    if killed:
        print("종료한 gunicorn PID:", killed)
    else:
        print("실행 중인 gunicorn 없음")
    # 포트(8080) 해제까지 충분히 대기
    time.sleep(5)


def start():
    env = dict(os.environ, GUNICORN_BIND="0.0.0.0:8080")
    py = os.path.join(BACKEND, ".venv", "bin", "python")
    log_path = os.path.join(BACKEND, "gunicorn.log")
    pid_path = os.path.join(BACKEND, "gunicorn.pid")
    # 이전 로그/pid 정리 (실패 원인 구분용)
    for p in (log_path, pid_path):
        try:
            os.remove(p)
        except OSError:
            pass

    subprocess.run(
        [
            py, "-m", "gunicorn", "-c", "gunicorn_conf.py", "app.main:app",
            "--daemon", "--pid", "gunicorn.pid",
            "--error-logfile", "gunicorn.log", "--access-logfile", "gunicorn.log",
        ],
        cwd=BACKEND,
        env=env,
        check=True,
    )
    time.sleep(5)

    if os.path.exists(pid_path):
        print("기동 완료. 새 PID:", open(pid_path).read().strip())
    else:
        print("[경고] PID 파일이 없습니다. gunicorn 기동에 실패했을 수 있습니다.")

    # 로그 끝부분 출력 (성공/실패 원인 확인)
    try:
        print("--- gunicorn.log 끝부분 ---")
        print(open(log_path).read()[-1800:])
    except OSError:
        print("(로그 파일 없음)")

    # 내부 헬스 체크
    try:
        import urllib.request

        body = urllib.request.urlopen(
            "http://127.0.0.1:8080/health", timeout=5
        ).read()
        print("내부 8080 응답:", body)
    except Exception as e:
        print("내부 8080 확인 실패:", e)


if __name__ == "__main__":
    kill_existing_gunicorn()
    start()
