"""오더(운송 주문) 서비스.

오더는 헤더(orders) + 자식 컬렉션(order_items / order_stops / order_charges /
order_references)으로 구성된 복합 애그리거트다. 등록/수정은 한 트랜잭션에서
헤더와 자식을 함께 처리한다.

- 모든 id 컬럼은 GENERATED ALWAYS AS IDENTITY 이므로 INSERT 시 id 를 넣지 않고
  RETURNING 으로 받는다.
- order_no 는 number_sequences 를 원자적으로 증가시켜 자동 채번한다.
- customer_id 는 business_partners.id 를 받되, customers 행이 없으면 자동 생성한다.
- 값은 모두 바인드 파라미터로 전달한다(SQL 인젝션 방지).
- PostgreSQL 11 호환 문법만 사용한다.
"""
from __future__ import annotations

from datetime import date
from typing import Any, Optional

from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.config import settings

SCHEMA = settings.DB_SCHEMA

# ── enum 정의 (프런트 드롭다운 + 검증 공용) ─────────────────────────
ORDER_STATUSES = [
    "draft", "confirmed", "planned", "tendered", "assigned",
    "in_transit", "delivered", "completed", "cancelled",
]
SERVICE_LEVELS = ["economy", "standard", "express", "same_day"]
EQUIPMENT_TYPES = [
    "van", "reefer", "flatbed", "wing", "tanker",
    "container_20", "container_40", "ltl_box", "parcel", "other",
]
STOP_TYPES = ["pickup", "delivery", "cross_dock"]
CHARGE_TYPES = ["base", "fuel", "accessorial", "tax", "discount", "adjustment"]

# 상태 전이 규칙. 키 상태에서 값 집합으로만 변경할 수 있다.
ALLOWED_TRANSITIONS: dict[str, set[str]] = {
    "draft": {"confirmed", "cancelled"},
    "confirmed": {"planned", "cancelled"},
    "planned": {"tendered", "cancelled"},
    "tendered": {"assigned", "cancelled"},
    "assigned": {"in_transit", "cancelled"},
    "in_transit": {"delivered", "cancelled"},
    "delivered": {"completed"},
    "completed": set(),
    "cancelled": set(),
}
# 자식(품목/배송지/부가요금/참조)까지 재구성 가능한 상태.
EDITABLE_STATUSES = {"draft", "confirmed", "planned"}


def _tbl(name: str) -> str:
    return f'"{SCHEMA}"."{name}"'


# ── 값 변환 헬퍼 ────────────────────────────────────────────────
def _s(v: Any) -> Optional[str]:
    """문자열로 정규화. 빈 값은 None."""
    if v is None:
        return None
    s = str(v).strip()
    return s or None


def _i(v: Any) -> Optional[int]:
    if v is None or (isinstance(v, str) and not v.strip()):
        return None
    try:
        return int(v)
    except (ValueError, TypeError):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "정수 형식이 올바르지 않습니다.")


def _n(v: Any) -> Optional[float]:
    if v is None or (isinstance(v, str) and not v.strip()):
        return None
    try:
        return float(v)
    except (ValueError, TypeError):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "숫자 형식이 올바르지 않습니다.")


def _b(v: Any) -> bool:
    if isinstance(v, bool):
        return v
    return str(v).strip().lower() in ("1", "true", "t", "y", "yes")


def _enum(v: Any, allowed: list[str], label: str, default: Optional[str] = None) -> Optional[str]:
    s = _s(v)
    if s is None:
        return default
    if s not in allowed:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"'{label}' 값이 올바르지 않습니다: {s}",
        )
    return s


# ── 채번 ────────────────────────────────────────────────────────
def next_order_no(db: Session, tenant_id: int) -> str:
    """number_sequences 를 원자적으로 증가시켜 오더 번호를 채번한다."""
    row = db.execute(
        text(
            f"INSERT INTO {_tbl('number_sequences')} (tenant_id, seq_type, prefix, last_value) "
            "VALUES (:t, 'ORDER', 'ORD', 1) "
            "ON CONFLICT (tenant_id, seq_type) "
            "DO UPDATE SET last_value = number_sequences.last_value + 1 "
            "RETURNING prefix, last_value"
        ),
        {"t": tenant_id},
    ).first()
    prefix, value = row[0], row[1]
    return f"{prefix}-{date.today():%Y%m}-{int(value):05d}"


def _ensure_customer(db: Session, tenant_id: int, partner_id: int) -> None:
    """business_partner 를 고객으로 쓸 수 있도록 customers 행을 보장한다."""
    exists = db.execute(
        text(
            f"SELECT 1 FROM {_tbl('business_partners')} "
            "WHERE id = :pid AND tenant_id = :t AND deleted_at IS NULL"
        ),
        {"pid": partner_id, "t": tenant_id},
    ).first()
    if exists is None:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "유효하지 않은 고객(거래처)입니다.")
    db.execute(
        text(
            f"INSERT INTO {_tbl('customers')} (partner_id, tenant_id) "
            "VALUES (:pid, :t) ON CONFLICT (partner_id) DO NOTHING"
        ),
        {"pid": partner_id, "t": tenant_id},
    )


# ── 룩업(드롭다운) ──────────────────────────────────────────────
def lookups(db: Session, tenant_id: int) -> dict:
    customers = [
        dict(r) for r in db.execute(
            text(
                f"SELECT id, code, name FROM {_tbl('business_partners')} "
                "WHERE tenant_id = :t AND deleted_at IS NULL ORDER BY name"
            ),
            {"t": tenant_id},
        ).mappings().all()
    ]
    locations = [
        dict(r) for r in db.execute(
            text(
                f"SELECT id, name, address FROM {_tbl('locations')} "
                "WHERE tenant_id = :t AND deleted_at IS NULL ORDER BY name"
            ),
            {"t": tenant_id},
        ).mappings().all()
    ]
    accessorials = [
        dict(r) for r in db.execute(
            text(
                f"SELECT id, code, name, default_rate FROM {_tbl('accessorial_types')} "
                "WHERE tenant_id = :t AND deleted_at IS NULL ORDER BY name"
            ),
            {"t": tenant_id},
        ).mappings().all()
    ]
    gl_codes = [
        dict(r) for r in db.execute(
            text(
                f"SELECT id, code, name FROM {_tbl('gl_codes')} "
                "WHERE tenant_id = :t AND deleted_at IS NULL ORDER BY code"
            ),
            {"t": tenant_id},
        ).mappings().all()
    ]
    currencies = [
        dict(r) for r in db.execute(
            text(f"SELECT code, name FROM {_tbl('currencies')} ORDER BY code")
        ).mappings().all()
    ]
    return {
        "customers": customers,
        "locations": locations,
        "accessorial_types": accessorials,
        "gl_codes": gl_codes,
        "currencies": currencies,
        "enums": {
            "order_status": ORDER_STATUSES,
            "service_level": SERVICE_LEVELS,
            "equipment_type": EQUIPMENT_TYPES,
            "stop_type": STOP_TYPES,
            "charge_type": CHARGE_TYPES,
        },
        "transitions": {k: sorted(v) for k, v in ALLOWED_TRANSITIONS.items()},
    }


# ── 목록 ────────────────────────────────────────────────────────
def list_orders(
    db: Session,
    *,
    tenant_id: int,
    q: Optional[str] = None,
    status_filter: Optional[str] = None,
    customer_id: Optional[int] = None,
    limit: int = 50,
    offset: int = 0,
) -> dict:
    where = ["o.tenant_id = :t"]
    params: dict[str, Any] = {"t": tenant_id}
    if q:
        where.append("(o.order_no ILIKE :q OR bp.name ILIKE :q)")
        params["q"] = f"%{q}%"
    if status_filter:
        where.append("o.status = :st")
        params["st"] = status_filter
    if customer_id:
        where.append("o.customer_id = :cid")
        params["cid"] = customer_id
    wsql = " WHERE " + " AND ".join(where)

    total = db.execute(
        text(
            f"SELECT COUNT(*) FROM {_tbl('orders')} o "
            f"LEFT JOIN {_tbl('business_partners')} bp ON bp.id = o.customer_id{wsql}"
        ),
        params,
    ).scalar()

    rows = db.execute(
        text(
            "SELECT o.id, o.order_no, o.status, o.service, o.requested_equipment, "
            "o.requested_pickup_at, o.requested_delivery_at, o.total_weight_kg, "
            "o.total_volume_cbm, o.currency, o.sell_amount, o.customer_id, "
            "bp.name AS customer_name, o.created_at "
            f"FROM {_tbl('orders')} o "
            f"LEFT JOIN {_tbl('business_partners')} bp ON bp.id = o.customer_id"
            f"{wsql} ORDER BY o.id DESC LIMIT :limit OFFSET :offset"
        ),
        {**params, "limit": limit, "offset": offset},
    ).mappings().all()

    return {
        "items": [dict(r) for r in rows],
        "total": total or 0,
        "limit": limit,
        "offset": offset,
    }


# ── 대시보드 요약 ───────────────────────────────────────────────
def summary(db: Session, *, tenant_id: int) -> dict:
    """오더 대시보드용 집계. 상태별 건수 + 오늘 등록 + 당월 매출을 한 번에 반환.

    상태별 건수는 단일 GROUP BY 한 번으로 구해 N번 호출을 피한다.
    PostgreSQL 11 호환 문법만 사용한다.
    """
    rows = db.execute(
        text(
            f"SELECT o.status AS status, COUNT(*) AS cnt "
            f"FROM {_tbl('orders')} o WHERE o.tenant_id = :t GROUP BY o.status"
        ),
        {"t": tenant_id},
    ).mappings().all()
    status_counts = {r["status"]: int(r["cnt"]) for r in rows}
    total = sum(status_counts.values())

    today = db.execute(
        text(
            f"SELECT COUNT(*) FROM {_tbl('orders')} "
            "WHERE tenant_id = :t AND created_at::date = CURRENT_DATE"
        ),
        {"t": tenant_id},
    ).scalar() or 0

    month_revenue = db.execute(
        text(
            f"SELECT COALESCE(SUM(sell_amount), 0) FROM {_tbl('orders')} "
            "WHERE tenant_id = :t AND status <> 'cancelled' "
            "AND created_at >= date_trunc('month', CURRENT_DATE)"
        ),
        {"t": tenant_id},
    ).scalar() or 0

    return {
        "total": total,
        "status_counts": status_counts,
        "today": int(today),
        "month_revenue": float(month_revenue),
    }


# ── 단건(자식 포함) ─────────────────────────────────────────────
def get_order(db: Session, *, tenant_id: int, order_id: int) -> dict:
    head = db.execute(
        text(
            "SELECT o.*, bp.name AS customer_name "
            f"FROM {_tbl('orders')} o "
            f"LEFT JOIN {_tbl('business_partners')} bp ON bp.id = o.customer_id "
            "WHERE o.id = :id AND o.tenant_id = :t"
        ),
        {"id": order_id, "t": tenant_id},
    ).mappings().first()
    if head is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "오더를 찾을 수 없습니다.")

    items = db.execute(
        text(
            "SELECT id, sku, description, quantity, package_type, weight_kg, volume_cbm, "
            "is_hazmat, un_number, hs_code, country_of_origin, customs_value, customs_currency "
            f"FROM {_tbl('order_items')} WHERE order_id = :id ORDER BY id"
        ),
        {"id": order_id},
    ).mappings().all()
    stops = db.execute(
        text(
            "SELECT id, seq, stop_type, location_id, address, window_from, window_to "
            f"FROM {_tbl('order_stops')} WHERE order_id = :id ORDER BY seq"
        ),
        {"id": order_id},
    ).mappings().all()
    charges = db.execute(
        text(
            "SELECT id, charge_type, accessorial_type_id, description, amount, currency, gl_code_id "
            f"FROM {_tbl('order_charges')} WHERE order_id = :id ORDER BY id"
        ),
        {"id": order_id},
    ).mappings().all()
    refs = db.execute(
        text(
            "SELECT id, ref_type, ref_value "
            f"FROM {_tbl('order_references')} WHERE order_id = :id ORDER BY id"
        ),
        {"id": order_id},
    ).mappings().all()

    result = dict(head)
    result["items"] = [dict(r) for r in items]
    result["stops"] = [dict(r) for r in stops]
    result["charges"] = [dict(r) for r in charges]
    result["references"] = [dict(r) for r in refs]
    return result


# ── 자식 INSERT 헬퍼 ────────────────────────────────────────────
def _insert_items(db: Session, order_id: int, items: list[dict]) -> None:
    for it in items:
        db.execute(
            text(
                f"INSERT INTO {_tbl('order_items')} "
                "(order_id, sku, description, quantity, package_type, weight_kg, volume_cbm, "
                " is_hazmat, un_number, hs_code, country_of_origin, customs_value, customs_currency) "
                "VALUES (:order_id, :sku, :description, :quantity, :package_type, :weight_kg, "
                " :volume_cbm, :is_hazmat, :un_number, :hs_code, :country_of_origin, "
                " :customs_value, :customs_currency)"
            ),
            {
                "order_id": order_id,
                "sku": _s(it.get("sku")),
                "description": _s(it.get("description")),
                "quantity": _n(it.get("quantity")) or 1,
                "package_type": _s(it.get("package_type")),
                "weight_kg": _n(it.get("weight_kg")),
                "volume_cbm": _n(it.get("volume_cbm")),
                "is_hazmat": _b(it.get("is_hazmat")),
                "un_number": _s(it.get("un_number")),
                "hs_code": _s(it.get("hs_code")),
                "country_of_origin": _s(it.get("country_of_origin")),
                "customs_value": _n(it.get("customs_value")),
                "customs_currency": _s(it.get("customs_currency")),
            },
        )


def _insert_stops(db: Session, order_id: int, stops: list[dict]) -> None:
    for idx, st in enumerate(stops, start=1):
        stop_type = _enum(st.get("stop_type"), STOP_TYPES, "정차 유형")
        if stop_type is None:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "정차지 유형은 필수입니다.")
        db.execute(
            text(
                f"INSERT INTO {_tbl('order_stops')} "
                "(order_id, seq, stop_type, location_id, address, window_from, window_to) "
                "VALUES (:order_id, :seq, :stop_type, :location_id, :address, :window_from, :window_to)"
            ),
            {
                "order_id": order_id,
                "seq": _i(st.get("seq")) or idx,
                "stop_type": stop_type,
                "location_id": _i(st.get("location_id")),
                "address": _s(st.get("address")),
                "window_from": _s(st.get("window_from")),
                "window_to": _s(st.get("window_to")),
            },
        )


def _insert_charges(db: Session, order_id: int, charges: list[dict]) -> None:
    for ch in charges:
        ctype = _enum(ch.get("charge_type"), CHARGE_TYPES, "요금 유형")
        if ctype is None:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "요금 유형은 필수입니다.")
        amount = _n(ch.get("amount"))
        if amount is None:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "요금 금액은 필수입니다.")
        db.execute(
            text(
                f"INSERT INTO {_tbl('order_charges')} "
                "(order_id, charge_type, accessorial_type_id, description, amount, currency, gl_code_id) "
                "VALUES (:order_id, :charge_type, :accessorial_type_id, :description, :amount, "
                " :currency, :gl_code_id)"
            ),
            {
                "order_id": order_id,
                "charge_type": ctype,
                "accessorial_type_id": _i(ch.get("accessorial_type_id")),
                "description": _s(ch.get("description")),
                "amount": amount,
                "currency": _s(ch.get("currency")) or "KRW",
                "gl_code_id": _i(ch.get("gl_code_id")),
            },
        )


def _insert_refs(db: Session, order_id: int, refs: list[dict]) -> None:
    for rf in refs:
        rtype = _s(rf.get("ref_type"))
        rval = _s(rf.get("ref_value"))
        if rtype is None or rval is None:
            continue  # 빈 참조 줄은 건너뜀
        db.execute(
            text(
                f"INSERT INTO {_tbl('order_references')} (order_id, ref_type, ref_value) "
                "VALUES (:order_id, :ref_type, :ref_value)"
            ),
            {"order_id": order_id, "ref_type": rtype, "ref_value": rval},
        )


def _totals(items: list[dict], charges: list[dict]) -> tuple[Optional[float], Optional[float], Optional[float]]:
    """품목에서 총중량/총부피, 부가요금에서 매출금액을 합산한다."""
    tw = sum((_n(i.get("weight_kg")) or 0) * (_n(i.get("quantity")) or 1) for i in items)
    tv = sum((_n(i.get("volume_cbm")) or 0) * (_n(i.get("quantity")) or 1) for i in items)
    sell = sum(_n(c.get("amount")) or 0 for c in charges)
    return (
        round(tw, 3) if items else None,
        round(tv, 3) if items else None,
        round(sell, 2) if charges else None,
    )


# ── 등록 ────────────────────────────────────────────────────────
def create_order(db: Session, *, tenant_id: int, user_id: int, payload: dict) -> dict:
    customer_id = _i(payload.get("customer_id"))
    if customer_id is None:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "고객(거래처)은 필수입니다.")

    items = payload.get("items") or []
    stops = payload.get("stops") or []
    charges = payload.get("charges") or []
    refs = payload.get("references") or []
    tw, tv, sell = _totals(items, charges)

    try:
        _ensure_customer(db, tenant_id, customer_id)
        order_no = _s(payload.get("order_no")) or next_order_no(db, tenant_id)
        new_id = db.execute(
            text(
                f"INSERT INTO {_tbl('orders')} "
                "(tenant_id, customer_id, order_no, status, service, requested_equipment, "
                " requested_pickup_at, requested_delivery_at, temperature_min_c, temperature_max_c, "
                " declared_value, total_weight_kg, total_volume_cbm, currency, sell_amount, notes, "
                " created_by, updated_by) "
                "VALUES (:tenant_id, :customer_id, :order_no, :status, :service, :equipment, "
                " :pickup, :delivery, :tmin, :tmax, :declared, :tw, :tv, :currency, :sell, :notes, "
                " :uid, :uid) RETURNING id"
            ),
            {
                "tenant_id": tenant_id,
                "customer_id": customer_id,
                "order_no": order_no,
                "status": _enum(payload.get("status"), ORDER_STATUSES, "상태", "draft"),
                "service": _enum(payload.get("service"), SERVICE_LEVELS, "서비스", "standard"),
                "equipment": _enum(payload.get("requested_equipment"), EQUIPMENT_TYPES, "장비"),
                "pickup": _s(payload.get("requested_pickup_at")),
                "delivery": _s(payload.get("requested_delivery_at")),
                "tmin": _n(payload.get("temperature_min_c")),
                "tmax": _n(payload.get("temperature_max_c")),
                "declared": _n(payload.get("declared_value")),
                "tw": tw,
                "tv": tv,
                "currency": _s(payload.get("currency")) or "KRW",
                "sell": sell,
                "notes": _s(payload.get("notes")),
                "uid": user_id,
            },
        ).scalar()

        _insert_items(db, new_id, items)
        _insert_stops(db, new_id, stops)
        _insert_charges(db, new_id, charges)
        _insert_refs(db, new_id, refs)
        db.commit()
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, _integrity_msg(e))
    except HTTPException:
        db.rollback()
        raise
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"등록 실패: {e.__class__.__name__}")
    return get_order(db, tenant_id=tenant_id, order_id=new_id)


# ── 수정 ────────────────────────────────────────────────────────
def update_order(db: Session, *, tenant_id: int, user_id: int, order_id: int, payload: dict) -> dict:
    current = get_order(db, tenant_id=tenant_id, order_id=order_id)
    if current["status"] not in EDITABLE_STATUSES:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"'{current['status']}' 상태의 오더는 수정할 수 없습니다.",
        )
    customer_id = _i(payload.get("customer_id")) or current["customer_id"]
    items = payload.get("items") or []
    stops = payload.get("stops") or []
    charges = payload.get("charges") or []
    refs = payload.get("references") or []
    tw, tv, sell = _totals(items, charges)

    try:
        _ensure_customer(db, tenant_id, customer_id)
        db.execute(
            text(
                f"UPDATE {_tbl('orders')} SET "
                "customer_id = :customer_id, service = :service, requested_equipment = :equipment, "
                "requested_pickup_at = :pickup, requested_delivery_at = :delivery, "
                "temperature_min_c = :tmin, temperature_max_c = :tmax, declared_value = :declared, "
                "total_weight_kg = :tw, total_volume_cbm = :tv, currency = :currency, "
                "sell_amount = :sell, notes = :notes, updated_by = :uid, updated_at = now() "
                "WHERE id = :id AND tenant_id = :t"
            ),
            {
                "customer_id": customer_id,
                "service": _enum(payload.get("service"), SERVICE_LEVELS, "서비스", "standard"),
                "equipment": _enum(payload.get("requested_equipment"), EQUIPMENT_TYPES, "장비"),
                "pickup": _s(payload.get("requested_pickup_at")),
                "delivery": _s(payload.get("requested_delivery_at")),
                "tmin": _n(payload.get("temperature_min_c")),
                "tmax": _n(payload.get("temperature_max_c")),
                "declared": _n(payload.get("declared_value")),
                "tw": tw,
                "tv": tv,
                "currency": _s(payload.get("currency")) or "KRW",
                "sell": sell,
                "notes": _s(payload.get("notes")),
                "uid": user_id,
                "id": order_id,
                "t": tenant_id,
            },
        )
        # 자식은 전량 교체
        for child in ("order_items", "order_stops", "order_charges", "order_references"):
            db.execute(text(f"DELETE FROM {_tbl(child)} WHERE order_id = :id"), {"id": order_id})
        _insert_items(db, order_id, items)
        _insert_stops(db, order_id, stops)
        _insert_charges(db, order_id, charges)
        _insert_refs(db, order_id, refs)
        db.commit()
    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, _integrity_msg(e))
    except HTTPException:
        db.rollback()
        raise
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"수정 실패: {e.__class__.__name__}")
    return get_order(db, tenant_id=tenant_id, order_id=order_id)


# ── 상태 변경 ───────────────────────────────────────────────────
def change_status(
    db: Session, *, tenant_id: int, user_id: int, order_id: int,
    to_status: str, reason: Optional[str] = None,
) -> dict:
    current = get_order(db, tenant_id=tenant_id, order_id=order_id)
    frm = current["status"]
    if to_status not in ORDER_STATUSES:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"알 수 없는 상태: {to_status}")
    if to_status not in ALLOWED_TRANSITIONS.get(frm, set()):
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"'{frm}' → '{to_status}' 상태 전이는 허용되지 않습니다.",
        )
    try:
        db.execute(
            text(
                f"UPDATE {_tbl('orders')} SET status = :st, updated_by = :uid, updated_at = now()"
                + (", cancel_reason = :reason" if to_status == "cancelled" else "")
                + " WHERE id = :id AND tenant_id = :t"
            ),
            {
                "st": to_status, "uid": user_id, "id": order_id, "t": tenant_id,
                **({"reason": _s(reason)} if to_status == "cancelled" else {}),
            },
        )
        db.execute(
            text(
                f"INSERT INTO {_tbl('status_history')} "
                "(entity_type, entity_id, from_status, to_status, changed_by) "
                "VALUES ('order', :id, :frm, :to, :uid)"
            ),
            {"id": order_id, "frm": frm, "to": to_status, "uid": user_id},
        )
        db.commit()
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"상태 변경 실패: {e.__class__.__name__}")
    return get_order(db, tenant_id=tenant_id, order_id=order_id)


# ── 삭제(초안만 하드 삭제) ──────────────────────────────────────
def delete_order(db: Session, *, tenant_id: int, order_id: int) -> None:
    current = get_order(db, tenant_id=tenant_id, order_id=order_id)
    if current["status"] != "draft":
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "초안(draft) 상태의 오더만 삭제할 수 있습니다. 그 외에는 취소 처리하세요.",
        )
    try:
        for child in ("order_items", "order_stops", "order_charges", "order_references"):
            db.execute(text(f"DELETE FROM {_tbl(child)} WHERE order_id = :id"), {"id": order_id})
        db.execute(
            text(f"DELETE FROM {_tbl('orders')} WHERE id = :id AND tenant_id = :t"),
            {"id": order_id, "t": tenant_id},
        )
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "다른 데이터가 참조 중이라 삭제할 수 없습니다.")


# ── 일괄 업로드 ─────────────────────────────────────────────────
def bulk_create(db: Session, *, tenant_id: int, user_id: int, rows: list[dict]) -> dict:
    """행 목록을 각각 오더로 등록한다. 행별 성공/실패를 모아 반환한다.

    각 행은 단일 품목·단일 배송지(픽업/배송 주소)를 가진 단순 오더로 간주한다.
    한 행의 실패가 다른 행에 영향을 주지 않도록 행 단위로 커밋한다.
    """
    results = []
    ok = 0
    for idx, row in enumerate(rows, start=1):
        try:
            payload = _row_to_order(row)
            created = create_order(db, tenant_id=tenant_id, user_id=user_id, payload=payload)
            ok += 1
            results.append({"row": idx, "ok": True, "order_no": created["order_no"], "id": created["id"]})
        except HTTPException as e:
            results.append({"row": idx, "ok": False, "error": e.detail})
        except Exception as e:  # noqa: BLE001
            results.append({"row": idx, "ok": False, "error": str(e)})
    return {"total": len(rows), "success": ok, "failed": len(rows) - ok, "results": results}


def _row_to_order(row: dict) -> dict:
    """일괄 업로드 한 행(평면 dict)을 오더 payload(중첩)로 변환한다."""
    items = []
    if any(row.get(k) for k in ("sku", "description", "quantity", "weight_kg", "volume_cbm")):
        items.append({
            "sku": row.get("sku"),
            "description": row.get("description"),
            "quantity": row.get("quantity") or 1,
            "weight_kg": row.get("weight_kg"),
            "volume_cbm": row.get("volume_cbm"),
            "package_type": row.get("package_type"),
        })
    stops = []
    if row.get("pickup_address"):
        stops.append({"stop_type": "pickup", "address": row.get("pickup_address"),
                      "window_from": row.get("pickup_at")})
    if row.get("delivery_address"):
        stops.append({"stop_type": "delivery", "address": row.get("delivery_address"),
                      "window_to": row.get("delivery_at")})
    return {
        "customer_id": row.get("customer_id"),
        "service": row.get("service") or "standard",
        "requested_equipment": row.get("requested_equipment"),
        "requested_pickup_at": row.get("pickup_at"),
        "requested_delivery_at": row.get("delivery_at"),
        "notes": row.get("notes"),
        "items": items,
        "stops": stops,
        "charges": [],
        "references": [],
    }


def _integrity_msg(e: IntegrityError) -> str:
    msg = str(getattr(e, "orig", e)).lower()
    if "order_no" in msg or "unique" in msg:
        return "오더 번호가 중복됩니다."
    return "제약 조건에 맞지 않는 값입니다."
