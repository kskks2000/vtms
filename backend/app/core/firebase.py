from __future__ import annotations

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.core.config import settings

# Firebase ID 토큰의 발급자는 항상 securetoken.google.com/<project_id> 형식이다.
_FIREBASE_ISSUER_PREFIX = "https://securetoken.google.com/"


class FirebaseAuthError(Exception):
    pass


def verify_firebase_id_token(token: str) -> dict:
    """Firebase ID 토큰을 검증하고 클레임을 반환한다.

    - 서명/만료 검증과 audience(=Firebase projectId) 검증은 google-auth 가 수행
    - issuer 와 이메일 존재 여부는 직접 확인
    - 이메일/비밀번호, Google 등 모든 Firebase 로그인 방식의 토큰을 처리한다
      (로그인 방식은 claims['firebase']['sign_in_provider'] 에 담긴다)
    """
    project_id = settings.FIREBASE_PROJECT_ID
    if not project_id:
        raise FirebaseAuthError("FIREBASE_PROJECT_ID 가 설정되지 않았습니다.")

    try:
        # audience=project_id 로 aud 클레임을 검증한다.
        claims = google_id_token.verify_firebase_token(
            token, google_requests.Request(), audience=project_id
        )
    except ValueError as e:
        raise FirebaseAuthError(f"유효하지 않은 Firebase 토큰입니다: {e}") from e

    if claims is None:
        raise FirebaseAuthError("Firebase 토큰을 검증하지 못했습니다.")

    expected_issuer = f"{_FIREBASE_ISSUER_PREFIX}{project_id}"
    if claims.get("iss") != expected_issuer:
        raise FirebaseAuthError("신뢰할 수 없는 토큰 발급자입니다.")
    if not claims.get("email"):
        raise FirebaseAuthError("토큰에 이메일이 없습니다.")

    return claims


def get_sign_in_provider(claims: dict) -> str:
    """claims 에서 로그인 방식(password, google.com 등)을 추출한다."""
    firebase = claims.get("firebase")
    if isinstance(firebase, dict):
        return firebase.get("sign_in_provider", "")
    return ""
