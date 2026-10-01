#!/usr/bin/env bash
# Proves the Trivy gate works both ways, using the same policy as CI:
#   1. the real image (Dockerfile) must PASS  -> trivy exit code 0
#   2. a deliberately vulnerable image must FAIL -> trivy exit code 1
# A build failure stops the script, so a missing image can never count as a "block".
set -euo pipefail

GOOD="devsecops-demo:gate-good"
BAD="devsecops-demo:gate-bad"
# Same flags as the blocking step in .github/workflows/phase-1-trivy.yml
TRIVY_GATE=(trivy image --quiet --scanners vuln --severity CRITICAL --exit-code 1)

echo "==> Building real image ($GOOD)"
docker build -q -t "$GOOD" . >/dev/null

echo "==> Building deliberately vulnerable image ($BAD)"
docker build -q -f tests/gates/Dockerfile.vulnerable -t "$BAD" . >/dev/null

echo ""
echo "==> [1/2] Gate on real image (expect PASS)"
set +e
"${TRIVY_GATE[@]}" "$GOOD"
GOOD_EXIT=$?
echo ""
echo "==> [2/2] Gate on vulnerable image (expect BLOCK)"
"${TRIVY_GATE[@]}" "$BAD"
BAD_EXIT=$?
set -e

echo ""
echo "real image:       trivy exit $GOOD_EXIT (want 0)"
echo "vulnerable image: trivy exit $BAD_EXIT (want 1)"

if [ "$GOOD_EXIT" -eq 0 ] && [ "$BAD_EXIT" -eq 1 ]; then
  echo "PROVEN: the gate passes a clean image and blocks a vulnerable one."
else
  echo "NOT PROVEN: the gate did not behave as expected."
  exit 1
fi
