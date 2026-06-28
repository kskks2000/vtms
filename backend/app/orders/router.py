"""오더(운송 주문) 라우터.

엔드포인트(모두 인증 필요):
  GET    /orders/_lookups        드롭다운/enum 메타 (화면 구성용)
  GET    /orders                 목록 (q, status, customer_id, limit, offset)
  GET    /orders/{id}            단건 (품목/배송지/부가요금/참조 포함)
  POST   /orders                 등록 (복합 애그리거트)
  PUT    /orders/{id}            수정 (복합 애그리거트)
  POST   /orders/{id}/status     상태 변경
  DELETE /orders/{id}            삭제(초안만)
  POST   /orders/bulk            일괄 등록
"""
from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Body, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.orders import service

router = APIRouter(prefix="/orders", tags=["orders"])


@router.get("/_lookups")
def order_lookups(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return service.lookups(db, tenant_id=user.tenant_id)


@router.get("")
def list_orders(
    q: Optional[str] = Query(None),
    status_filter: Optional[str] = Query(None, alias="status"),
    customer_id: Optional[int] = Query(None),
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return service.list_orders(
        db,
        tenant_id=user.tenant_id,
        q=q,
        status_filter=status_filter,
        customer_id=customer_id,
        limit=limit,
        offset=offset,
    )


@router.get("/{order_id}")
def get_order(
    order_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return service.get_order(db, tenant_id=user.tenant_id, order_id=order_id)


@router.post("", status_code=status.HTTP_201_CREATED)
def create_order(
    payload: dict = Body(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return service.create_order(
        db, tenant_id=user.tenant_id, user_id=user.id, payload=payload
    )


@router.put("/{order_id}")
def update_order(
    order_id: int,
    payload: dict = Body(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return service.update_order(
        db, tenant_id=user.tenant_id, user_id=user.id, order_id=order_id, payload=payload
    )


@router.post("/{order_id}/status")
def change_status(
    order_id: int,
    payload: dict = Body(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return service.change_status(
        db,
        tenant_id=user.tenant_id,
        user_id=user.id,
        order_id=order_id,
        to_status=payload.get("status", ""),
        reason=payload.get("reason"),
    )


@router.delete("/{order_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_order(
    order_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    service.delete_order(db, tenant_id=user.tenant_id, order_id=order_id)
    return None


@router.post("/bulk")
def bulk_create(
    payload: dict = Body(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    rows = payload.get("rows") or []
    return service.bulk_create(db, tenant_id=user.tenant_id, user_id=user.id, rows=rows)
