#!/usr/bin/env bash
# Run Trivy scans locally before pushing — fast feedback loop.
# Same policy as CI: CRITICAL blocks, HIGH is reported but does not block.
set -euo pipefail

IMAGE_NAME="devsecops-demo:local"
EXIT_CODE=0

echo "==> Building image..."
docker build -t "$IMAGE_NAME" .

echo
echo "==> [1/3] Trivy filesystem scan (requirements.txt, report only)..."
trivy fs --scanners vuln --severity HIGH,CRITICAL app/requirements.txt

echo
echo "==> [2/3] Trivy image scan (HIGH, report only)..."
trivy image --quiet --scanners vuln --severity HIGH "$IMAGE_NAME"

echo
echo "==> [3/3] Trivy image scan (CRITICAL, BLOCKING)..."
trivy image --scanners vuln --severity CRITICAL --exit-code 1 "$IMAGE_NAME" || EXIT_CODE=1

if [[ "$EXIT_CODE" -ne 0 ]]; then
  echo
  echo "FAILED: CRITICAL vulnerabilities found. Fix before pushing." >&2
  exit 1
fi

echo
echo "PASSED: No CRITICAL vulnerabilities found."
