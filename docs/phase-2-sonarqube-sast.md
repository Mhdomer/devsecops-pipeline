# Phase 2 — SonarQube SAST Gate

## Goal

Add a Static Application Security Testing (SAST) gate using SonarQube Community
Edition. The pipeline **blocks a deploy if the SonarQube Quality Gate fails** —
covering code smells, bugs, and security hotspots in the Python source code.

## Why this matters (interview story)

Trivy (Phase 1) catches vulnerabilities in *packages and the OS*. It cannot read
your own code. SonarQube fills that gap — it reads your source and finds issues like
hardcoded secrets, SQL injection risks, insecure deserialization, and poor error
handling before they ever reach production.

Having both is the "shift-left" story: you're finding different classes of vulnerability
at different layers, automatically, before any human reviewer sees the code.

## What we're building

```
Phase 1 (Trivy) passes
        │
        ▼
GitHub Actions: Run SonarQube scan
        │
    SonarQube analyses Python source
        │
    ┌───┴────────────────────────────┐
    │ Quality Gate passed?           │
    │                                │
   NO                              YES
    │                                │
    ▼                                ▼
Pipeline FAILS              Continue to Phase 3 (ZAP)
(deploy is blocked)
```

## SonarQube setup options

| Option | Pros | Cons |
|--------|------|------|
| SonarCloud (SaaS) | Zero infra, free for public repos | Requires public repo or paid plan |
| Self-hosted on EC2 | Full control, private repos | Requires a running SonarQube server |
| Docker Compose (local) | Free, private, no cloud needed | Must keep container running during CI |

**We will use SonarCloud** — free for public repos, no server to manage, integrates
directly with GitHub Actions via a token.

## Files created in this phase

```
├── sonarqube/
│   └── sonar-project.properties    # SonarQube project config
├── .github/
│   └── workflows/
│       └── phase-2-sonarqube.yml   # GitHub Actions: SAST gate
```

## What SonarQube checks (relevant to this project)

| Category | Example finding |
|----------|----------------|
| Security hotspot | Use of `eval()`, hardcoded credentials |
| Vulnerability | SQL injection risk, XSS in templates |
| Bug | Unhandled exception paths |
| Code smell | Dead code, overly complex functions |

## Gate logic

```yaml
- name: SonarCloud Scan
  uses: SonarSource/sonarcloud-github-action@master
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
  with:
    args: >
      -Dsonar.qualitygate.wait=true   # blocks until gate result is known
```

`qualitygate.wait=true` is what makes this a gate, not just a report.

## Prerequisites

- SonarCloud account (free at sonarcloud.io)
- GitHub repo linked to SonarCloud
- `SONAR_TOKEN` added as a GitHub Actions secret

## How to test the gate

1. **Normal run** — clean Flask app should pass the default Quality Gate
2. **Break the gate** — add `import subprocess; subprocess.call(input())` to app.py
   (command injection risk — SonarQube will flag it)
3. **Fix** — remove it, gate passes again

## Checkpoint questions for Phase 2

1. What is the difference between SAST and DAST?
2. Why can't Trivy catch what SonarQube catches?
3. What is a Quality Gate in SonarQube?
4. What does `qualitygate.wait=true` do and what happens without it?
5. Why is SonarCloud used here instead of a self-hosted SonarQube server?

## Success criteria for Phase 2

- [ ] SonarCloud project created and linked to GitHub repo
- [ ] `SONAR_TOKEN` secret added to GitHub Actions
- [ ] Pipeline runs SonarQube scan on every push to `main`
- [ ] Results visible in SonarCloud dashboard
- [ ] Pipeline **fails** when a security hotspot is introduced
- [ ] Pipeline **passes** when source is clean

## Files created in this phase

```
├── sonarqube/
│   └── sonar-project.properties    ✅ project key, org, source/test paths, coverage
├── .github/
│   └── workflows/
│       └── phase-2-sonarqube.yml   ✅ 3 jobs: test+coverage → sonarcloud scan → summary
```

## Implementation status

| Item | Status |
|------|--------|
| All files created | ✅ Done |
| SonarCloud account + project setup | ⏳ Manual step required |
| `SONAR_TOKEN` added to GitHub secrets | ⏳ Manual step required |
| Pipeline run validated | ⏳ Pending push + SonarCloud setup |
| Intentional break test | ⏳ Pending |

## Manual setup steps (do these before pushing)

1. Go to [sonarcloud.io](https://sonarcloud.io) and sign in with GitHub
2. Click **+** → **Analyze new project** → select `Mhdomer/devsecops-pipeline`
3. Choose **GitHub Actions** as the analysis method
4. Copy the generated `SONAR_TOKEN`
5. In your GitHub repo → **Settings → Secrets → Actions** → add `SONAR_TOKEN`
6. Push — the pipeline will trigger automatically

## Previous phase

[Phase 1 — Docker + Trivy](phase-1-docker-trivy.md)

## Next phase

[Phase 3 — OWASP ZAP DAST Gate](phase-3-owasp-zap-dast.md)
