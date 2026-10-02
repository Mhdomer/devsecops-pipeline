#!/usr/bin/env bash
# ZAP baseline scan + DAST gate. Used by CI (.github/workflows/phase-3-zap.yml)
# and locally (scripts/prove-zap-gate.sh), so both run the same thing.
#
#   TARGET       URL ZAP scans                  (default http://localhost:5000)
#   ZAP_NETWORK  docker network for ZAP         (default host; use b2-net locally on Docker Desktop)
#   OUT_DIR      where reports are written      (default zap-out)
#
# Exit: 0 pass, 1 blocked by the gate, 2 scan error.
set -euo pipefail

# Pinned by digest: the same ZAP rules engine locally and in CI.
ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable@sha256:781a2bdaea47324e7bab583e2263f21d257b0aee61ed51521a5be45f5f5081ef"
ZAP_UID=1000                                    # the image's "zap" user
TARGET="${TARGET:-http://localhost:5000}"
ZAP_NETWORK="${ZAP_NETWORK:-host}"
OUT_DIR="${OUT_DIR:-zap-out}"
ZAP_CONTAINER="zap-scan-$$"
STAGE="$(mktemp -d)"

if python3 -c "" 2>/dev/null; then PYTHON=python3; else PYTHON=python; fi
export MSYS_NO_PATHCONV=1                       # Git Bash on Windows: don't rewrite /zap/wrk

cleanup() {
  docker rm -f "$ZAP_CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$STAGE"
  return 0
}
trap cleanup EXIT

mkdir -p "$OUT_DIR"
OUT_ABS="$(cd "$OUT_DIR" && (pwd -W 2>/dev/null || pwd))"

# ZAP writes its reports to /zap/wrk. Instead of bind-mounting a host directory
# (which would have to be world-writable for the container's zap user), stream a
# wrk/ directory owned by that user into the container, then copy reports out.
echo "==> ZAP baseline scan against $TARGET"
docker create --name "$ZAP_CONTAINER" --network "$ZAP_NETWORK" "$ZAP_IMAGE" \
  zap-baseline.py -t "$TARGET" -c zap-baseline.conf \
  -J zap-report.json -r zap-report.html -I -s >/dev/null
mkdir "$STAGE/wrk"
cp zap/zap-baseline.conf "$STAGE/wrk/"
tar -C "$STAGE" --owner="$ZAP_UID" --group="$ZAP_UID" --numeric-owner -cf - wrk \
  | docker cp -a - "$ZAP_CONTAINER:/zap"

ZAP_EXIT=0
docker start -a "$ZAP_CONTAINER" || ZAP_EXIT=$?
for report in zap-report.json zap-report.html; do
  docker cp "$ZAP_CONTAINER:/zap/wrk/$report" "$OUT_DIR/" 2>/dev/null || true
done

# zap-baseline: 0 clean, 1 FAIL rule hit, 2 warnings (suppressed by -I), 3 scan error.
if [[ "$ZAP_EXIT" -ge 3 ]] || [[ ! -s "$OUT_DIR/zap-report.json" ]]; then
  echo "ZAP scan error (exit $ZAP_EXIT), no usable report." >&2
  exit 2
fi

echo
echo "==> DAST gate"
"$PYTHON" zap/zap_gate.py "$OUT_ABS/zap-report.json" zap/zap-baseline.conf
