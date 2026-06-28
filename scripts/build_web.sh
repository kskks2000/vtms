#!/usr/bin/env bash
# Flutter 웹을 배포용으로 빌드한다. (로컬 Mac에서 실행)
#
# 같은 도메인에서 FastAPI 가 정적 서빙하므로 API_BASE_URL 을 비워
# 앱이 상대경로(/api/...)로 백엔드를 호출하게 한다.
#
# 보안: Firebase/Google 키는 소스에 하드코딩하지 않고, 루트 .env 에서 읽어
# --dart-define 으로 주입한다. (.env 는 .gitignore 로 커밋되지 않음)
#
# 결과물: build/web  → 이 폴더 전체를 서버로 업로드
set -euo pipefail

cd "$(dirname "$0")/.."

# .env 로드 (있으면)
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

# --dart-define 인자 구성: .env 에 값이 있는 키만 주입한다.
DEFINES=("--dart-define=API_BASE_URL=${API_BASE_URL:-}")
for key in \
  FIREBASE_WEB_API_KEY FIREBASE_WEB_APP_ID FIREBASE_MESSAGING_SENDER_ID \
  FIREBASE_PROJECT_ID FIREBASE_AUTH_DOMAIN FIREBASE_STORAGE_BUCKET \
  FIREBASE_ANDROID_API_KEY FIREBASE_ANDROID_APP_ID \
  GOOGLE_WEB_CLIENT_ID GOOGLE_SERVER_CLIENT_ID; do
  val="${!key:-}"
  if [[ -n "$val" ]]; then
    DEFINES+=("--dart-define=${key}=${val}")
  fi
done

flutter pub get
flutter build web --release "${DEFINES[@]}"

echo
echo "빌드 완료: $(pwd)/build/web"
echo "주입된 정의 수: ${#DEFINES[@]}"
echo "이 폴더의 내용을 서버의 FRONTEND_DIST 경로로 업로드하세요."
