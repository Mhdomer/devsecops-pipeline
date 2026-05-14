# Phase 1 — Docker + Trivy (Container Scanning Gate)

## Goal

Containerize the Flask app using Docker best practices, then wire Trivy into GitHub
Actions so the pipeline **automatically blocks a deploy if CRITICAL CVEs are found**
in the container image.

## Why this matters (interview story)

Container scanning is the first and most impactful security gate in a DevSecOps
pipeline. It catches known CVEs in base images and dependencies *before* anything
reaches production. Being able to say "I block deploys automatically on CRITICAL
findings, not just report them" is exactly what interviewers are probing for in
DevSecOps/Cloud security roles.

## What we're building

```
Developer pushes code
        │
        ▼
GitHub Actions: Build Docker image
        │
        ▼
Trivy scans image for CVEs
        │
    ┌───┴────────────────────────────┐
    │ CRITICAL CVEs found?           │
    │                                │
   YES                              NO
    │                                │
    ▼                                ▼
Pipeline FAILS              Continue to next stage
(deploy is blocked)         (Phase 2: SonarQube)
```

## Files created in this phase

```
├── app/
│   ├── __init__.py             ✅
│   ├── app.py                  ✅ Flask app (3 routes: /, /health, /api/items)
│   ├── requirements.txt        ✅ Pinned: flask==2.3.3, gunicorn==21.2.0, werkzeug==2.3.7
│   └── tests/
│       ├── __init__.py         ✅
│       └── test_app.py         ✅ 5 pytest unit tests
├── Dockerfile                  ✅ Multi-stage, non-root user, healthcheck
├── .dockerignore               ✅
├── docker-compose.yml          ✅ Local dev
├── pytest.ini                  ✅ testpaths = app/tests
├── .github/
│   └── workflows/
│       └── phase-1-trivy.yml   ✅ 4 jobs: test → build → trivy-scan → summary
└── scripts/
    └── trivy-local.sh          ✅ Local Trivy scan script
```

## Security practices demonstrated (Trivy will verify these)

| Practice | How |
|----------|-----|
| Non-root user | `adduser appuser`, `USER appuser` in Dockerfile |
| Multi-stage build | Separate builder and runtime stages |
| Minimal base image | `python:3.11-slim` not full `python:3.11` |
| No secrets in image | `.dockerignore` excludes `.env` files |
| Pinned dep versions | `requirements.txt` uses exact versions |
| Healthcheck | `HEALTHCHECK` instruction in Dockerfile |

## Trivy scan targets

1. **Filesystem scan** — Python packages in `requirements.txt`
2. **Image scan** — the built Docker image (OS packages + Python packages)

## Gate logic

```yaml
# In GitHub Actions
- name: Trivy image scan
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: devsecops-demo:${{ github.sha }}
    exit-code: '1'           # <-- makes the step FAIL on findings
    severity: 'CRITICAL'     # block only on CRITICAL; report HIGH
    format: 'sarif'
    output: 'trivy-results.sarif'
```

`exit-code: '1'` on CRITICAL severity is what actually blocks the pipeline.

## Prerequisites

- Docker Desktop installed locally
- GitHub repo with Actions enabled
- Trivy installed locally (`winget install aquasecurity.trivy` on Windows)

## How to test the gate

1. **Normal run** — image should pass (clean base image, pinned deps)
2. **Break the gate** — change base image to `python:3.6` (EOL, many CVEs) →
   pipeline should fail with CRITICAL findings
3. **Fix** — revert to `python:3.11-slim` → pipeline passes again

## Success criteria for Phase 1

- [ ] `docker build` succeeds locally
- [ ] `docker run` starts the app on port 5000
- [ ] `GET /health` returns `{"status": "healthy"}`
- [ ] `trivy image devsecops-demo:latest` runs clean (0 CRITICAL) locally
- [ ] GitHub Actions workflow runs on every push to `main`
- [ ] Pipeline **fails** when tested with a vulnerable base image
- [ ] Pipeline **passes** with the hardened Dockerfile
- [ ] Trivy SARIF results uploaded to GitHub Security tab

## Implementation status

| Item | Status |
|------|--------|
| All files created | ✅ Done |
| Pushed to GitHub | ⏳ Pending (daily commit) |
| Pipeline run validated | ⏳ Pending first push |
| Intentional break test | ⏳ Pending |

## Next phase

[Phase 2 — SonarQube SAST Gate](phase-2-sonarqube-sast.md)
