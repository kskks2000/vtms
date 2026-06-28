from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.user import User


def get_active_user_by_email(db: Session, email: str) -> User | None:
    stmt = (
        select(User)
        .where(func.lower(User.email) == email.lower())
        .where(User.deleted_at.is_(None))
        .order_by(User.id)
        .limit(1)
    )
    return db.execute(stmt).scalar_one_or_none()


def get_active_user_by_id(db: Session, user_id: int) -> User | None:
    stmt = (
        select(User)
        .where(User.id == user_id)
        .where(User.deleted_at.is_(None))
    )
    return db.execute(stmt).scalar_one_or_none()


def get_role_codes(db: Session, user_id: int) -> list[str]:
    rows = db.execute(
        text(
            "SELECT r.code FROM user_roles ur "
            "JOIN roles r ON r.id = ur.role_id "
            "WHERE ur.user_id = :uid ORDER BY r.code"
        ),
        {"uid": user_id},
    ).all()
    return [r[0] for r in rows]


def get_permission_codes(db: Session, user_id: int) -> list[str]:
    rows = db.execute(
        text(
            "SELECT DISTINCT p.code FROM user_roles ur "
            "JOIN role_permissions rp ON rp.role_id = ur.role_id "
            "JOIN permissions p ON p.id = rp.permission_id "
            "WHERE ur.user_id = :uid ORDER BY p.code"
        ),
        {"uid": user_id},
    ).all()
    return [r[0] for r in rows]


def is_locked(user: User) -> bool:
    return user.locked_until is not None and user.locked_until > datetime.now(
        timezone.utc
    )


def record_login_success(db: Session, user: User) -> None:
    user.failed_login_count = 0
    user.locked_until = None
    user.last_login_at = datetime.now(timezone.utc)
    db.commit()


def record_login_failure(db: Session, user: User) -> None:
    user.failed_login_count = (user.failed_login_count or 0) + 1
    if user.failed_login_count >= settings.MAX_FAILED_LOGIN:
        user.locked_until = datetime.now(timezone.utc) + timedelta(
            minutes=settings.LOCK_MINUTES
        )
    db.commit()


def link_external_auth(db: Session, user: User, sub: str) -> None:
    if user.external_auth_id != sub:
        user.external_auth_id = sub
        db.commit()


def create_external_user(
    db: Session, *, email: str, full_name: str, sub: str, tenant_id: int
) -> User:
    """외부 인증(Google, Firebase 등) 사용자를 신규 생성한다."""
    user = User(
        tenant_id=tenant_id,
        email=email,
        full_name=full_name or email.split("@")[0],
        external_auth_id=sub,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# 하위 호환용 별칭.
def create_google_user(
    db: Session, *, email: str, full_name: str, sub: str, tenant_id: int
) -> User:
    return create_external_user(
        db, email=email, full_name=full_name, sub=sub, tenant_id=tenant_id
    )
