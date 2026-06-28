#!/usr/bin/env bash
# Flutter 웹을 배포용으로 빌드한다. (로컬 Mac에서 실행)
#
# 같은 도메인에서 FastAPI 가 정적 서빙하므로 API_BASE_URL 을 비워
# 앱이 상대경로(/api/...)로 백엔드를 호출하게 한다.
#
# 결과물: build/web  → 이 폴더 전체를 서버로 업로드
set -euo pipefail

cd "$(dirname "$0")/.."

flutter pub get
flutter build web --release --dart-define=API_BASE_URL=

echo
echo "빌드 완료: $(pwd)/build/web"
echo "이 폴더의 내용을 서버의 FRONTEND_DIST 경로로 업로드하세요."
