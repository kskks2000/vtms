"""vtms 스키마의 테이블 구조를 컴팩트하게 덤프한다.

backend 디렉터리에서 실행:
    python3 scripts/dump_schema.py > /web/vtms/schema.txt

테이블별로 컬럼(타입/NULL/기본값), 기본키, 외래키, 유니크, 행 수를 출력한다.
비밀번호 등 데이터 값은 출력하지 않는다(구조만).
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import inspect, text  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db.session import engine  # noqa: E402


def main() -> None:
    schema = settings.DB_SCHEMA
    with engine.connect() as conn:
        try:
            ver = conn.execute(text("SHOW server_version")).scalar()
            print(f"# PostgreSQL {ver} / schema={schema}")
        except Exception:
            print(f"# schema={schema}")

        insp = inspect(conn)
        tables = sorted(insp.get_table_names(schema=schema))
        print(f"# tables: {len(tables)}")
        print(f"# names: {', '.join(tables)}")
        print()

        for t in tables:
            try:
                count = conn.execute(
                    text(f'SELECT COUNT(*) FROM "{schema}"."{t}"')
                ).scalar()
            except Exception:
                count = "?"
            print(f"== {t}  (rows={count})")

            pk = insp.get_pk_constraint(t, schema=schema).get(
                "constrained_columns", []
            )
            for c in insp.get_columns(t, schema=schema):
                flags = []
                if c["name"] in pk:
                    flags.append("PK")
                if not c.get("nullable", True):
                    flags.append("NOT NULL")
                default = c.get("default")
                if default is not None:
                    flags.append(f"default={default}")
                flagstr = ("  [" + ", ".join(flags) + "]") if flags else ""
                print(f"   - {c['name']}: {c['type']}{flagstr}")

            for fk in insp.get_foreign_keys(t, schema=schema):
                cols = ", ".join(fk.get("constrained_columns", []))
                rt = fk.get("referred_table")
                rcols = ", ".join(fk.get("referred_columns", []))
                print(f"   FK ({cols}) -> {rt}({rcols})")

            for uq in insp.get_unique_constraints(t, schema=schema):
                cols = ", ".join(uq.get("column_names", []))
                print(f"   UNIQUE ({cols})")

            print()


if __name__ == "__main__":
    main()
