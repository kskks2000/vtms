#!/usr/bin/env bash
# VTMS 전체 재배포 (백엔드 + 웹). Mac에서 한 번 실행: bash redeploy.sh
# 각 단계에서 서버 비밀번호를 물어볼 수 있습니다(여러 번). 그대로 입력하세요.
set -e

HOST="logis@www.logistics.ai.kr"
SSH="ssh -o HostKeyAlgorithms=+ssh-rsa"
SCP="scp -o HostKeyAlgorithms=+ssh-rsa"

cd "$(dirname "$0")"

echo "==> [1/5] 백엔드 압축"
tar czf /tmp/vtms-backend.tgz -C backend \
  --exclude=.venv --exclude=.env --exclude=__pycache__ .

echo "==> [2/5] 백엔드 업로드 + 압축 해제"
$SCP /tmp/vtms-backend.tgz "$HOST:/web/"
$SSH "$HOST" "python3 -c \"import tarfile; tarfile.open('/web/vtms-backend.tgz').extractall('/web/vtms/backend')\" && rm /web/vtms-backend.tgz && echo backend-extracted"

echo "==> [3/5] 백엔드 재기동 (gunicorn 8080)"
$SSH "$HOST" "cd /web/vtms/backend && python3 scripts/restart_gabia.py"

echo "==> [4/5] 웹 빌드 (flutter)"
flutter build web --release --dart-define=API_BASE_URL=

echo "==> [5/5] 웹 업로드"
tar czf /tmp/vtms-web.tgz -C build/web .
$SCP /tmp/vtms-web.tgz "$HOST:/web/"
$SSH "$HOST" "rm -rf /web/vtms/web && mkdir -p /web/vtms/web && python3 -c \"import tarfile; tarfile.open('/web/vtms-web.tgz').extractall('/web/vtms/web')\" && rm /web/vtms-web.tgz && echo web-extracted"

echo
echo "✅ 완료. http://www.logistics.ai.kr/ 에서 확인하세요."
