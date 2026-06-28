"""마스터 범용 CRUD 라우터.

엔드포인트(모두 인증 필요):
  GET    /master/_meta             전체 마스터 메타(키/라벨/컬럼) - 화면 구성용
  GET    /master/{key}             목록 (q, limit, offset)
  GET    /master/{key}/{id}        단건
  POST   /master/{key}             등록
  PUT    /master/{key}/{id}        수정
  DELETE /master/{key}/{id}        삭제(소프트/하드)
"""
from __future__ import annotations

from dataclasses import asdict
from typing import Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.masters import service
from app.masters.config import MASTERS, MASTERS_BY_KEY, MasterConfig
from app.models.user import User

router = APIRouter(prefix="/master", tags=["master"])


def _cfg(key: str) -> MasterConfig:
    cfg = MASTERS_BY_KEY.get(key)
    if cfg is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"알 수 없는 마스터: {key}",
        )
    return cfg


@router.get("/_meta")
def meta():
    """전체 마스터의 키/라벨/컬럼 메타데이터."""
    return {
        "masters": [
            {
                "key": m.key,
                "label": m.label,
                "subtitle": m.subtitle,
                "pk": m.pk,
                "soft_delete": m.soft_delete_col is not None,
                "columns": [asdict(c) for c in m.columns],
            }
            for m in MASTERS
        ]
    }


@router.get("/{key}")
def list_master(
    key: str,
    q: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return service.list_rows(
        db, _cfg(key), tenant_id=user.tenant_id, q=q, limit=limit, offset=offset
    )


@router.get("/{key}/{row_id}")
def get_master(
    key: str,
    row_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return service.get_row(db, _cfg(key), tenant_id=user.tenant_id, row_id=row_id)


@router.post("/{key}", status_code=status.HTTP_201_CREATED)
def create_master(
    key: str,
    payload: dict = Body(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return service.create_row(db, _cfg(key), tenant_id=user.tenant_id, payload=payload)


@router.put("/{key}/{row_id}")
def update_master(
    key: str,
    row_id: int,
    payload: dict = Body(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return service.update_row(
        db, _cfg(key), tenant_id=user.tenant_id, row_id=row_id, payload=payload
    )


@router.delete("/{key}/{row_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_master(
    key: str,
    row_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    service.delete_row(db, _cfg(key), tenant_id=user.tenant_id, row_id=row_id)
    return None
