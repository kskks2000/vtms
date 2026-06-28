from __future__ import annotations

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.core.config import settings

_ALLOWED_ISSUERS = {"accounts.google.com", "https://accounts.google.com"}


class GoogleAuthError(Exception):
    pass


def verify_google_id_token(token: str) -> dict:
    """구글 ID 토큰을 검증하고 클레임을 반환한다.

    - 서명/만료 검증은 google-auth 가 수행
    - audience(클라이언트 ID)와 issuer, 이메일 인증 여부는 직접 확인
    """
    if not settings.google_client_ids:
        raise GoogleAuthError("GOOGLE_CLIENT_IDS 가 설정되지 않았습니다.")

    try:
        # audience=None 으로 받고 aud 는 아래에서 직접 검증
        claims = google_id_token.verify_oauth2_token(
            token, google_requests.Request()
        )
    except ValueError as e:
        raise GoogleAuthError(f"유효하지 않은 구글 토큰입니다: {e}") from e

    if claims.get("iss") not in _ALLOWED_ISSUERS:
        raise GoogleAuthError("신뢰할 수 없는 토큰 발급자입니다.")
    if claims.get("aud") not in settings.google_client_ids:
        raise GoogleAuthError("허용되지 않은 클라이언트 ID 입니다.")
    if not claims.get("email"):
        raise GoogleAuthError("토큰에 이메일이 없습니다.")
    if claims.get("email_verified") is not True:
        raise GoogleAuthError("이메일이 검증되지 않은 구글 계정입니다.")

    return claims
