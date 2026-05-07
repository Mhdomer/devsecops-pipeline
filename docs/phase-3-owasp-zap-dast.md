# Phase 3 — OWASP ZAP DAST Gate

## Goal

Add a Dynamic Application Security Testing (DAST) gate using OWASP ZAP. The
pipeline **spins up the running app, attacks it with ZAP, and blocks the deploy if
HIGH or CRITICAL web vulnerabilities are found**.

## Why this matters (interview story)

Trivy scans the image. SonarQube reads the code. Neither of them runs the app.
ZAP does — it acts like an attacker, sending real HTTP requests to a live instance
of your app and looking for vulnerabilities that only appear at runtime: missing
security headers, open redirects, CSRF weaknesses, server information leakage.

This is the most "real world" gate in the pipeline and the one that most clearly
demonstrates you understand the full attack surface, not just the code.

## What we're building

```
Phase 2 (SonarQube) passes
        │
        ▼
GitHub Actions: Start app in Docker
        │
        ▼
OWASP ZAP runs baseline scan against http://localhost:5000
        │
    ┌───┴────────────────────────────────────────┐
    │ HIGH or CRITICAL web vulns found?          │
    │                                            │
   YES                                          NO
    │                                            │
    ▼                                            ▼
Pipeline FAILS                        Continue to Phase 4 (Deploy)
(deploy is blocked)
```

## ZAP scan types

| Scan type | What it does | Speed |
|-----------|-------------|-------|
| Baseline scan | Passive only — observes traffic, no active attacks | Fast (~2 min) |
| Full scan | Active attacks — sends malicious payloads | Slow (~20 min) |
| API scan | Targets OpenAPI/Swagger specs | Medium |

**We use the baseline scan** in CI — fast enough for a pipeline, still catches
the most common web vulnerabilities. Full scan can be run on a schedule.

## Files created in this phase

```
├── zap/
│   └── zap-baseline.conf           # ZAP rules configuration
├── .github/
│   └── workflows/
│       └── phase-3-zap.yml         # GitHub Actions: DAST gate
```

## What ZAP baseline scan checks

| Check | What it catches |
|-------|----------------|
| Missing security headers | No `X-Content-Type-Options`, `X-Frame-Options` |
| Cookie flags | Cookies without `HttpOnly` or `Secure` flags |
| Server header leakage | Response reveals server software/version |
| CORS misconfiguration | Overly permissive cross-origin policy |
| Information disclosure | Stack traces, debug info in responses |

## Gate logic

```yaml
- name: ZAP Baseline Scan
  uses: zaproxy/action-baseline@v0.12.0
  with:
    target: 'http://localhost:5000'
    rules_file_name: 'zap/zap-baseline.conf'
    fail_action: true    # pipeline fails on WARN or higher
    artifact_name: 'zap-report'
```

## How the app runs during ZAP scan

ZAP needs a live target. In the pipeline:

```yaml
- name: Start app
  run: docker run -d -p 5000:5000 --name app devsecops-demo:${{ github.sha }}

- name: Wait for app to be ready
  run: |
    for i in {1..10}; do
      curl -s http://localhost:5000/health && break
      sleep 3
    done
```

## How to test the gate

1. **Normal run** — bare Flask app will likely have some missing headers (ZAP
   will report them — we then fix them)
2. **Add security headers** — use Flask's `after_request` to add headers; ZAP
   passes
3. **Break intentionally** — remove headers again; ZAP fails the gate

## Fixing the headers (preview for implementation)

```python
@app.after_request
def set_security_headers(response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    return response
```

## Checkpoint questions for Phase 3

1. What is the difference between SAST and DAST — in one sentence each?
2. Why does DAST require a running app when SAST does not?
3. What is a missing `X-Content-Type-Options` header and what attack does it enable?
4. Why do we use the baseline scan in CI instead of the full scan?
5. What is the risk of having `X-Frame-Options` missing?

## Success criteria for Phase 3

- [ ] App starts successfully in Docker during the pipeline
- [ ] ZAP baseline scan runs against the live app
- [ ] ZAP report uploaded as a pipeline artifact
- [ ] Pipeline **fails** before security headers are added
- [ ] Pipeline **passes** after security headers are added to Flask app
- [ ] ZAP HTML report readable in GitHub Actions artifacts

## Previous phase

[Phase 2 — SonarQube SAST Gate](phase-2-sonarqube-sast.md)

## Next phase

[Phase 4 — Terraform Infra + EC2 Deploy](phase-4-terraform-deploy.md)
