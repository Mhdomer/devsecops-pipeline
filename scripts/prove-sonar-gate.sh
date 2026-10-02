#!/usr/bin/env bash
# Proves the SonarQube Quality Gate works both ways, with the same scanner
# settings as CI (sonarqube/sonar-project.properties + qualitygate.wait):
#   1. the clean source must PASS     -> scanner exit code 0
#   2. source with planted findings   -> scanner exit code non-zero
#      (tests/gates/sonar-planted-issue.patch: hardcoded Flask secret key,
#       DEBUG=True, hardcoded password; app.py is restored automatically afterwards)
#
# Usage:
#   Local server:  SONAR_TOKEN=<token> scripts/prove-sonar-gate.sh
#                  (expects a SonarQube container named b2-sonar on network b2-net)
#   SonarCloud:    SONAR_HOST_URL=https://sonarcloud.io SONAR_TOKEN=<token> scripts/prove-sonar-gate.sh
#
# Everything runs in containers, so coverage.xml paths match what the scanner sees.
set -euo pipefail

: "${SONAR_TOKEN:?set SONAR_TOKEN}"
SONAR_HOST_URL="${SONAR_HOST_URL:-http://b2-sonar:9000}"
NETWORK="${NETWORK:-b2-net}"
PATCH="tests/gates/sonar-planted-issue.patch"

export MSYS_NO_PATHCONV=1                       # Git Bash on Windows: don't rewrite /usr/src
REPO="$(pwd -W 2>/dev/null || pwd)"

run_coverage() {
  docker run --rm -v "$REPO:/usr/src" -w /usr/src python:3.11-slim \
    sh -c "pip install -q --root-user-action=ignore --require-hashes --only-binary :all: -r requirements-dev.txt && pytest -q --cov=app --cov=zap --cov-report=xml:coverage.xml" >/dev/null
  return 0
}

run_scan() {
  local log rc=0
  log="$(mktemp)"
  docker run --rm --network "$NETWORK" -v "$REPO:/usr/src" \
    -e SONAR_HOST_URL="$SONAR_HOST_URL" -e SONAR_TOKEN="$SONAR_TOKEN" \
    sonarsource/sonar-scanner-cli \
    -Dproject.settings=sonarqube/sonar-project.properties \
    -Dsonar.qualitygate.wait=true -Dsonar.qualitygate.timeout=300 \
    >"$log" 2>&1 || rc=$?
  grep -E "QUALITY GATE|EXECUTION (SUCCESS|FAILURE)|ERROR" "$log" || true
  rm -f "$log"
  return "$rc"
}

BACKUP="$(mktemp)"
cp app/app.py "$BACKUP"
# Restore the exact original bytes (a reverse patch can trip over line endings).
revert() {
  cp "$BACKUP" app/app.py
  return 0
}

echo "==> [1/2] Clean source (expect PASS)"
run_coverage
set +e; run_scan; CLEAN_EXIT=$?; set -e

echo
echo "==> [2/2] Planted findings (expect BLOCK)"
trap revert EXIT
git apply "$PATCH"
run_coverage
set +e; run_scan; BAD_EXIT=$?; set -e
revert; trap - EXIT; rm -f "$BACKUP"

echo
echo "clean source:     scanner exit $CLEAN_EXIT (want 0)"
echo "planted findings: scanner exit $BAD_EXIT (want non-zero)"

if [[ "$CLEAN_EXIT" -eq 0 ]] && [[ "$BAD_EXIT" -ne 0 ]]; then
  echo "PROVEN: the Quality Gate passes clean code and blocks planted findings."
else
  echo "NOT PROVEN: the gate did not behave as expected." >&2
  exit 1
fi
