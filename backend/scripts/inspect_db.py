"""DB 접속 점검 스크립트.

backend 디렉터리에서 실행:
    python scripts/inspect_db.py

.env 의 DATABASE_URL 로 접속해서 테이블 목록 / 컬럼 / 행 수를 출력하고,
users 테이블이 있으면 안전한 컬럼(비밀번호 제외)만 보여준다.
"""
from __future__ import annotations

import os
import sys

# backend 루트를 import 경로에 추가 (app 패키지 인식용)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import inspect, text  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db.session import engine  # noqa: E402


def main() -> None:
    # 비밀번호는 가려서 출력
    safe_url = settings.DATABASE_URL
    if "@" in safe_url:
        head, tail = safe_url.split("@", 1)
        if ":" in head:
            scheme_user = head.rsplit(":", 1)[0]
            safe_url = f"{scheme_user}:****@{tail}"
    print(f"접속 대상: {safe_url}\n")

    try:
        with engine.connect() as conn:
            ver = conn.execute(text("SHOW server_version")).scalar()
            print(f"PostgreSQL 서버 버전: {ver}\n")

            inspector = inspect(conn)
            tables = inspector.get_table_names(schema=settings.DB_SCHEMA)
            if not tables:
                print("테이블이 없습니다. (서버를 한 번 기동하면 users 테이블이 생성됩니다)")
                return

            print(f"테이블 {len(tables)}개: {', '.join(tables)}\n")
            for t in tables:
                cols = inspector.get_columns(t)
                count = conn.execute(text(f'SELECT COUNT(*) FROM "{t}"')).scalar()
                col_desc = ", ".join(f"{c['name']}:{c['type']}" for c in cols)
                print(f"■ {t}  (행 {count})")
                print(f"   컬럼: {col_desc}")

                if t == "users":
                    rows = conn.execute(
                        text(
                            "SELECT id, email, name, is_active, created_at "
                            "FROM users ORDER BY id"
                        )
                    ).fetchall()
                    for r in rows:
                        print(f"   - #{r[0]} {r[1]} ({r[2]}) active={r[3]} created={r[4]}")
                print()
    except Exception as e:
        print(f"[접속 실패] {type(e).__name__}: {e}")
        print("\n확인하세요:")
        print(" 1) PostgreSQL 11 이 실행 중인가")
        print(" 2) .env 의 DATABASE_URL 사용자/비밀번호/DB명이 맞는가")
        print(" 3) 해당 DB(vtms 등)와 사용자가 생성돼 있는가")
        sys.exit(1)


if __name__ == "__main__":
    main()
