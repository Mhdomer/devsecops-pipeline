#!/usr/bin/env bash
# Run Trivy scans locally before pushing — fast feedback loop
set -euo pipefail

IMAGE_NAME="devsecops-demo:local"
EXIT_CODE=0

echo "==> Building image..."
docker build -t "$IMAGE_NAME" .

echo ""
echo "==> [1/2] Trivy filesystem scan (requirements.txt)..."
trivy fs \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  app/requirements.txt || EXIT_CODE=1

echo ""
echo "==> [2/2] Trivy image scan..."
trivy image \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  "$IMAGE_NAME" || EXIT_CODE=1

if [ "$EXIT_CODE" -ne 0 ]; then
  echo ""
  echo "FAILED: CRITICAL/HIGH vulnerabilities found. Fix before pushing."
  exit 1
fi

echo ""
echo "PASSED: No CRITICAL/HIGH vulnerabilities found."
