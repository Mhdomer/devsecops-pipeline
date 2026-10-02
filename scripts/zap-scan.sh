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
TARGET="${TARGET:-http://localhost:5000}"
ZAP_NETWORK="${ZAP_NETWORK:-host}"
OUT_DIR="${OUT_DIR:-zap-out}"

if python3 -c "" 2>/dev/null; then PYTHON=python3; else PYTHON=python; fi
export MSYS_NO_PATHCONV=1                       # Git Bash on Windows: don't rewrite /zap/wrk

mkdir -p "$OUT_DIR"
chmod 777 "$OUT_DIR"                            # ZAP runs as uid 1000 inside the container
cp zap/zap-baseline.conf "$OUT_DIR/"
OUT_ABS="$(cd "$OUT_DIR" && (pwd -W 2>/dev/null || pwd))"

echo "==> ZAP baseline scan against $TARGET"
set +e
docker run --rm --network "$ZAP_NETWORK" -v "$OUT_ABS:/zap/wrk:rw" "$ZAP_IMAGE" \
  zap-baseline.py -t "$TARGET" -c zap-baseline.conf \
  -J zap-report.json -r zap-report.html -I -s
ZAP_EXIT=$?
set -e

# zap-baseline: 0 clean, 1 FAIL rule hit, 2 warnings (suppressed by -I), 3 scan error.
if [ "$ZAP_EXIT" -ge 3 ] || [ ! -s "$OUT_DIR/zap-report.json" ]; then
  echo "ZAP scan error (exit $ZAP_EXIT), no usable report."
  exit 2
fi

echo ""
echo "==> DAST gate"
"$PYTHON" zap/zap_gate.py "$OUT_ABS/zap-report.json" zap/zap-baseline.conf
