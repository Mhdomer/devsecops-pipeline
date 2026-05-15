# Learning Journal

A personal record of what was built, understood, and questioned each session.
Used for interview prep — read this before any DevSecOps interview.

---

## Session — 2026-05-08 | Phase 1: Docker + Trivy

### What I built
- Full project structure with phase-based planning docs (`docs/`, `PHASES.md`)
- Flask app with 3 routes and 5 pytest unit tests
- Hardened multi-stage Dockerfile (non-root user, slim base, healthcheck)
- GitHub Actions workflow: unit tests → Docker build → Trivy scan (CRITICAL gate) → summary
- Local Trivy scan script (`scripts/trivy-local.sh`)
- Learning checkpoint system (`learning/phase-1-checkpoint.md`)

### What I actually understand now

**Multi-stage builds:** The builder stage installs packages into `/install` using
`--prefix`. The final stage copies only `/install` — no build tools, no cache, no
compiler. Smaller image and reduced attack surface.

**Non-root user:** Docker defaults to UID 0 = same as host root. A container
breakout with root = game over on the host. `adduser appuser` + `USER appuser`
means a breakout lands as a restricted user.

**Trivy:** Reads package manifests (not source code). Compares installed package
versions against NVD + GitHub Advisory databases. `exit-code: '1'` is what turns
a report into a gate — without it the pipeline ignores findings.

**CRITICAL vs HIGH CVEs:** CRITICAL = no preconditions, remote, full impact.
HIGH = at least one friction factor (user interaction, auth required, partial impact).
CVSS scores: CRITICAL 9.0–10.0, HIGH 7.0–8.9.

**`python:latest` problem:** It's a moving target — different image every pull.
Pinning to `3.11-slim` means reproducible builds and consistent Trivy scan results.

**`--prefix=/install`:** Redirects pip's install location so packages land in
a separate directory that can be cleanly copied into the final stage.

### What confused me
- Initially confused `WORKDIR /build` (a directory) with `AS builder` (a stage name).
  These are completely independent — the directory name has no relation to the stage name.
- Thought `--no-cache-dir` was about Docker layer cache. It's about pip's own download
  cache — a different thing entirely.
- Thought Trivy "reads the codebase" — it doesn't. It reads package metadata only.
  Source code analysis is SonarQube's job (Phase 2).

### Questions I still have
- How does Trivy handle packages that are installed at runtime vs build time?
- What happens if the base image (`python:3.11-slim`) itself has a CRITICAL CVE —
  does that fail the gate even if my code/deps are clean?
- Can Trivy scan the filesystem scan and image scan in one step or must they be separate?

### One thing I could explain to someone right now
Why `exit-code: '1'` is the single most important line in the Trivy GitHub Action —
without it you have a security report, not a security gate. The distinction between
reporting and blocking is the whole point of DevSecOps.

---

---

## Session — 2026-05-08 | Phase 2: SonarQube SAST

### What I built
- `sonarqube/sonar-project.properties` — links the repo to SonarCloud, configures
  source paths, Python version, and coverage report location
- `pytest-cov` added to the test step to generate `coverage.xml` for SonarCloud
- `.github/workflows/phase-2-sonarqube.yml` — 3-job pipeline: tests+coverage →
  SonarCloud SAST scan (with `qualitygate.wait=true`) → summary
- `learning/phase-2-checkpoint.md` — checkpoint questions to answer before validation

### What requires manual setup before this phase validates
- SonarCloud account creation and project linking (sonarcloud.io → GitHub OAuth)
- `SONAR_TOKEN` generated in SonarCloud and added as a GitHub Actions secret

### Checkpoint Q&A
⏳ Pending — answer questions in `learning/phase-2-checkpoint.md` before validating.

---

*Add a new session entry each time you work on this project.*
