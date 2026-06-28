"""개발용 시드. 기본 테넌트와 관리자 계정을 보장한다.

실제 vtms 스키마에 맞춰 동작하며, 이미 있으면 건너뛴다.
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_password
from app.crud import user as user_crud
from app.models.role import Role
from app.models.tenant import Tenant
from app.models.user import User


def _ensure_tenant(db: Session) -> Tenant:
    tenant = (
        db.query(Tenant).filter(Tenant.code == settings.DEFAULT_TENANT_CODE).first()
    )
    if tenant:
        return tenant
    tenant = Tenant(
        code=settings.DEFAULT_TENANT_CODE, name=settings.DEFAULT_TENANT_NAME
    )
    db.add(tenant)
    db.commit()
    db.refresh(tenant)
    return tenant


def _assign_role(db: Session, user_id: int, role_code: str) -> None:
    role = db.query(Role).filter(Role.code == role_code).first()
    if role is None:
        return
    exists = db.execute(
        text("SELECT 1 FROM user_roles WHERE user_id=:u AND role_id=:r"),
        {"u": user_id, "r": role.id},
    ).first()
    if exists:
        return
    db.execute(
        text(
            "INSERT INTO user_roles (user_id, role_id, granted_at) "
            "VALUES (:u, :r, :t)"
        ),
        {"u": user_id, "r": role.id, "t": datetime.now(timezone.utc)},
    )
    db.commit()


def seed_admin(db: Session) -> None:
    tenant = _ensure_tenant(db)

    user = user_crud.get_active_user_by_email(db, settings.SEED_USER_EMAIL)
    if user is None:
        user = User(
            tenant_id=tenant.id,
            email=settings.SEED_USER_EMAIL,
            full_name=settings.SEED_USER_NAME,
            password_hash=hash_password(settings.SEED_USER_PASSWORD),
            is_active=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    _assign_role(db, user.id, "admin")
