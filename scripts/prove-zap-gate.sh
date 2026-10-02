#!/usr/bin/env bash
# Proves the ZAP DAST gate works both ways, with the same scan and gate as CI
# (scripts/zap-scan.sh):
#   1. the real app (security headers on)    -> gate exit 0
#   2. the app with headers removed           -> gate exit 1
#      (tests/gates/zap-remove-headers.patch is applied only for the image build;
#       app.py is restored straight after)
# A build or scan error stops the script, so an error can never count as a "block".
set -euo pipefail

NET=b2-net-zapproof
GOOD="devsecops-demo:zap-good"
BAD="devsecops-demo:zap-bad"
PATCH="tests/gates/zap-remove-headers.patch"

cleanup() {
  docker rm -f zap-target >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Building real image ($GOOD)"
docker build -q -t "$GOOD" . >/dev/null

echo "==> Building image with security headers removed ($BAD)"
BACKUP="$(mktemp)"
cp app/app.py "$BACKUP"
git apply "$PATCH"
docker build -q -t "$BAD" . >/dev/null || { cp "$BACKUP" app/app.py; exit 1; }
cp "$BACKUP" app/app.py; rm -f "$BACKUP"

docker network create "$NET" >/dev/null

scan() {   # $1 image, $2 out dir; prints gate output, returns the gate's exit code
  docker rm -f zap-target >/dev/null 2>&1 || true
  docker run -d --name zap-target --network "$NET" "$1" >/dev/null
  for _ in $(seq 1 30); do
    docker exec zap-target python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" 2>/dev/null && break
    sleep 1
  done
  local rc=0
  TARGET=http://zap-target:5000 ZAP_NETWORK="$NET" OUT_DIR="$2" bash scripts/zap-scan.sh || rc=$?
  return "$rc"
}

echo ""
echo "==> [1/2] Real app (expect PASS)"
GOOD_EXIT=0; scan "$GOOD" zap-out/good || GOOD_EXIT=$?
echo ""
echo "==> [2/2] Headers removed (expect BLOCK)"
BAD_EXIT=0; scan "$BAD" zap-out/bad || BAD_EXIT=$?

echo ""
echo "real app:        gate exit $GOOD_EXIT (want 0)"
echo "headers removed: gate exit $BAD_EXIT (want 1)"

if [ "$GOOD_EXIT" -eq 0 ] && [ "$BAD_EXIT" -eq 1 ]; then
  echo "PROVEN: the DAST gate passes the hardened app and blocks the unhardened one."
else
  echo "NOT PROVEN: the gate did not behave as expected."
  exit 1
fi
