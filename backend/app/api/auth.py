from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.firebase import (
    FirebaseAuthError,
    get_sign_in_provider,
    verify_firebase_id_token,
)
from app.core.google import GoogleAuthError, verify_google_id_token
from app.core.security import create_access_token, verify_password
from app.crud import user as user_crud
from app.db.session import get_db
from app.models.tenant import Tenant
from app.models.user import User
from app.schemas.auth import (
    FirebaseLoginRequest,
    GoogleLoginRequest,
    LoginRequest,
    TokenResponse,
    UserOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _build_user_out(db: Session, user: User) -> UserOut:
    return UserOut(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        is_active=user.is_active,
        roles=user_crud.get_role_codes(db, user.id),
        permissions=user_crud.get_permission_codes(db, user.id),
    )


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    invalid = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="이메일 또는 비밀번호가 올바르지 않습니다.",
    )

    user = user_crud.get_active_user_by_email(db, payload.email)
    if user is None:
        raise invalid

    if user_crud.is_locked(user):
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail=f"계정이 잠겼습니다. {settings.LOCK_MINUTES}분 후 다시 시도하세요.",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="비활성화된 계정입니다."
        )

    if not user.password_hash or not verify_password(
        payload.password, user.password_hash
    ):
        user_crud.record_login_failure(db, user)
        raise invalid

    user_crud.record_login_success(db, user)
    return TokenResponse(access_token=create_access_token(subject=str(user.id)))


@router.post("/google", response_model=TokenResponse)
def google_login(payload: GoogleLoginRequest, db: Session = Depends(get_db)):
    try:
        claims = verify_google_id_token(payload.id_token)
    except GoogleAuthError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        )

    email = claims["email"]
    sub = claims["sub"]
    full_name = claims.get("name", "")

    user = user_crud.get_active_user_by_email(db, email)

    if user is None:
        if not settings.GOOGLE_AUTO_PROVISION:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="등록되지 않은 계정입니다. 관리자에게 문의하세요.",
            )
        tenant = db.query(Tenant).order_by(Tenant.id).first()
        if tenant is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="기본 테넌트가 없어 계정을 생성할 수 없습니다.",
            )
        user = user_crud.create_google_user(
            db, email=email, full_name=full_name, sub=sub, tenant_id=tenant.id
        )
    else:
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="비활성화된 계정입니다."
            )
        user_crud.link_external_auth(db, user, sub)

    user_crud.record_login_success(db, user)
    return TokenResponse(access_token=create_access_token(subject=str(user.id)))


@router.post("/firebase", response_model=TokenResponse)
def firebase_login(payload: FirebaseLoginRequest, db: Session = Depends(get_db)):
    """Firebase ID 토큰으로 로그인한다.

    이메일/비밀번호, Google 등 Firebase 가 발급한 모든 ID 토큰을 처리한다.
    Firebase 가 클라이언트 인증을 수행하고, 백엔드는 토큰을 검증한 뒤
    내부 사용자와 매핑하여 자체 JWT 액세스 토큰을 발급한다.
    """
    try:
        claims = verify_firebase_id_token(payload.id_token)
    except FirebaseAuthError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        )

    email = claims["email"]
    sub = claims["sub"]
    full_name = claims.get("name", "")
    email_verified = claims.get("email_verified") is True
    # 로그인 방식(password / google.com 등).
    provider = get_sign_in_provider(claims)
    is_google = provider == "google.com"

    user = user_crud.get_active_user_by_email(db, email)

    if user is None:
        # 자동 가입 허용 여부:
        #  - Google 계정: FIREBASE_GOOGLE_AUTO_PROVISION (이메일 인증 보장)
        #  - 그 외(이메일/비밀번호 등): FIREBASE_AUTO_PROVISION
        allow_provision = (
            settings.FIREBASE_GOOGLE_AUTO_PROVISION
            if is_google
            else settings.FIREBASE_AUTO_PROVISION
        )
        if not allow_provision:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="등록되지 않은 계정입니다. 관리자에게 문의하세요.",
            )
        # 자동 생성 시에는 이메일 인증을 완료한 토큰만 허용한다.
        if not email_verified:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="이메일 인증이 완료되지 않았습니다. 메일을 확인해 주세요.",
            )
        tenant = db.query(Tenant).order_by(Tenant.id).first()
        if tenant is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="기본 테넌트가 없어 계정을 생성할 수 없습니다.",
            )
        user = user_crud.create_external_user(
            db, email=email, full_name=full_name, sub=sub, tenant_id=tenant.id
        )
    else:
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="비활성화된 계정입니다."
            )
        if user_crud.is_locked(user):
            raise HTTPException(
                status_code=status.HTTP_423_LOCKED,
                detail=f"계정이 잠겼습니다. {settings.LOCK_MINUTES}분 후 다시 시도하세요.",
            )
        user_crud.link_external_auth(db, user, sub)

    user_crud.record_login_success(db, user)
    return TokenResponse(access_token=create_access_token(subject=str(user.id)))


@router.get("/me", response_model=UserOut)
def me(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _build_user_out(db, current_user)
