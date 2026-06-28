"""마스터 범용 CRUD 서비스 (SQLAlchemy Core 기반).

테이블/컬럼명은 MasterConfig(코드 정의)에서만 오므로 SQL 인젝션 위험이 없고,
값은 모두 바인드 파라미터로 전달한다.
"""
from __future__ import annotations

from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.masters.config import Column, MasterConfig

SCHEMA = settings.DB_SCHEMA


def _tbl(cfg: MasterConfig) -> str:
    return f'"{SCHEMA}"."{cfg.table}"'


def _select_cols(cfg: MasterConfig) -> str:
    return ", ".join(f'"{c.name}"' for c in cfg.columns)


def _coerce(col: Column, value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, str) and value.strip() == "":
        return None
    try:
        if col.type == "int":
            return int(value)
        if col.type == "number":
            return float(value)
        if col.type == "bool":
            if isinstance(value, bool):
                return value
            return str(value).lower() in ("1", "true", "t", "y", "yes")
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"'{col.label}' 값의 형식이 올바르지 않습니다.",
        )
    return value


def list_rows(
    db: Session,
    cfg: MasterConfig,
    *,
    tenant_id: int,
    q: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> dict:
    where: list[str] = []
    params: dict[str, Any] = {}
    if cfg.tenant_col:
        where.append(f'"{cfg.tenant_col}" = :tenant_id')
        params["tenant_id"] = tenant_id
    if cfg.soft_delete_col:
        where.append(f'"{cfg.soft_delete_col}" IS NULL')
    if q and cfg.search_columns:
        ors = " OR ".join(f'"{c}"::text ILIKE :q' for c in cfg.search_columns)
        where.append(f"({ors})")
        params["q"] = f"%{q}%"
    wsql = (" WHERE " + " AND ".join(where)) if where else ""

    total = db.execute(
        text(f"SELECT COUNT(*) FROM {_tbl(cfg)}{wsql}"), params
    ).scalar()

    rows = (
        db.execute(
            text(
                f"SELECT {_select_cols(cfg)} FROM {_tbl(cfg)}{wsql} "
                f'ORDER BY "{cfg.order_by}" DESC LIMIT :limit OFFSET :offset'
            ),
            {**params, "limit": limit, "offset": offset},
        )
        .mappings()
        .all()
    )
    return {
        "items": [dict(r) for r in rows],
        "total": total or 0,
        "limit": limit,
        "offset": offset,
    }


def get_row(db: Session, cfg: MasterConfig, *, tenant_id: int, row_id: int) -> dict:
    where = [f'"{cfg.pk}" = :id']
    params: dict[str, Any] = {"id": row_id}
    if cfg.tenant_col:
        where.append(f'"{cfg.tenant_col}" = :tenant_id')
        params["tenant_id"] = tenant_id
    if cfg.soft_delete_col:
        where.append(f'"{cfg.soft_delete_col}" IS NULL')
    row = (
        db.execute(
            text(
                f"SELECT {_select_cols(cfg)} FROM {_tbl(cfg)} "
                f"WHERE {' AND '.join(where)}"
            ),
            params,
        )
        .mappings()
        .first()
    )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="데이터를 찾을 수 없습니다."
        )
    return dict(row)


def _clean_payload(cfg: MasterConfig, payload: dict, *, for_create: bool) -> dict:
    editable = {c.name: c for c in cfg.editable_columns}
    data: dict[str, Any] = {}
    for name, col in editable.items():
        if name in payload:
            data[name] = _coerce(col, payload[name])
    if for_create:
        for col in cfg.editable_columns:
            if col.required and (data.get(col.name) is None):
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"'{col.label}' 은(는) 필수 항목입니다.",
                )
    return data


def create_row(
    db: Session, cfg: MasterConfig, *, tenant_id: int, payload: dict
) -> dict:
    data = _clean_payload(cfg, payload, for_create=True)
    if cfg.tenant_col:
        data[cfg.tenant_col] = tenant_id
    cols = ", ".join(f'"{k}"' for k in data)
    binds = ", ".join(f":{k}" for k in data)
    try:
        new_id = db.execute(
            text(
                f"INSERT INTO {_tbl(cfg)} ({cols}) VALUES ({binds}) "
                f'RETURNING "{cfg.pk}"'
            ),
            data,
        ).scalar()
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="중복되거나 제약 조건에 맞지 않는 값입니다.",
        )
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"등록 실패: {e.__class__.__name__}")
    return get_row(db, cfg, tenant_id=tenant_id, row_id=new_id)


def update_row(
    db: Session, cfg: MasterConfig, *, tenant_id: int, row_id: int, payload: dict
) -> dict:
    get_row(db, cfg, tenant_id=tenant_id, row_id=row_id)  # 존재/권한 확인
    data = _clean_payload(cfg, payload, for_create=False)
    if not data:
        return get_row(db, cfg, tenant_id=tenant_id, row_id=row_id)
    sets = [f'"{k}" = :{k}' for k in data]
    if any(c.name == "updated_at" for c in cfg.columns):
        sets.append('"updated_at" = now()')
    params = {**data, "id": row_id}
    where = [f'"{cfg.pk}" = :id']
    if cfg.tenant_col:
        where.append(f'"{cfg.tenant_col}" = :tenant_id')
        params["tenant_id"] = tenant_id
    try:
        db.execute(
            text(
                f"UPDATE {_tbl(cfg)} SET {', '.join(sets)} "
                f"WHERE {' AND '.join(where)}"
            ),
            params,
        )
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="중복되거나 제약 조건에 맞지 않는 값입니다.",
        )
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"수정 실패: {e.__class__.__name__}")
    return get_row(db, cfg, tenant_id=tenant_id, row_id=row_id)


def delete_row(db: Session, cfg: MasterConfig, *, tenant_id: int, row_id: int) -> None:
    get_row(db, cfg, tenant_id=tenant_id, row_id=row_id)
    params: dict[str, Any] = {"id": row_id}
    where = [f'"{cfg.pk}" = :id']
    if cfg.tenant_col:
        where.append(f'"{cfg.tenant_col}" = :tenant_id')
        params["tenant_id"] = tenant_id
    if cfg.soft_delete_col:
        sql = (
            f'UPDATE {_tbl(cfg)} SET "{cfg.soft_delete_col}" = now() '
            f"WHERE {' AND '.join(where)}"
        )
    else:
        sql = f"DELETE FROM {_tbl(cfg)} WHERE {' AND '.join(where)}"
    try:
        db.execute(text(sql), params)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="다른 데이터가 참조 중이라 삭제할 수 없습니다.",
        )
