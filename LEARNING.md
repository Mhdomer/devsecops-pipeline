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

## Session — 2026-10-02 | Phases 1–4: fix the gates, prove them, build infra offline

> Written by Claude from the session. Read `docs/reviews/2026-10-02.md`, then rewrite the
> "understand" parts in my own words. That's the part that counts in an interview.

### What I built
- Found why both May CI runs failed (details below) and fixed the workflows
- Patched deps (gunicorn, werkzeug had HIGH CVEs), pinned the base image by digest,
  removed pip/setuptools/wheel from the final image
- `scripts/prove-trivy-gate.sh`, `prove-sonar-gate.sh`, `prove-zap-gate.sh`: each runs the
  gate on a clean build and on a deliberately broken one and checks the exit codes
- Phase 3: security headers in Flask, ZAP baseline scan + `zap/zap_gate.py`, new workflow
- Phase 4: Terraform (EC2 t3.micro, ECR, OIDC deploy role), `terraform test` with a mocked
  AWS provider, deploy job disabled until the account is funded
- `docs/aws-runbook.md`: the AWS steps, cost and teardown, not run yet

### What I actually understand now

**Why the Trivy gate failed in May:** with `format: sarif`, trivy-action throws away the
`severity` filter (so the SARIF report has everything). `exit-code: 1` then fires on *any*
CVE, LOW included. The gate looked like "block on CRITICAL" but was really "block on
anything". Fix: one table-format step that blocks on CRITICAL, one SARIF step that never blocks.

**Why the SonarCloud gate failed:** `SONAR_TOKEN` was never added as a secret. The action it
used is also deprecated.

**Unfixed CVEs still need to block:** the vulnerable test image (Debian 10, end of life) only
had 2 CRITICALs and both were `will_not_fix`. With `ignore-unfixed: true` it would have
passed. An EOL OS gets no fixes, so "unfixed" is exactly the risk.

**Sonar's quality gate only looks at new code:** "Sonar way" checks new issues, coverage on
new code, duplication on new code. Old problems don't block. A planted bug only fails the
gate if it lands in what Sonar counts as new code.

**DAST severity vs what you actually want to enforce:** ZAP rates missing headers Low or
Medium. A "High only" gate would never block the bare app. So the gate blocks on High *or*
on a list of rules we've decided are mandatory (`zap/zap-baseline.conf`).

**OIDC instead of access keys:** GitHub gives the job a signed token; AWS trusts it only if
it comes from `repo:Mhdomer/devsecops-pipeline:ref:refs/heads/main`. Credentials last an hour
and there's nothing to leak or rotate.

### What confused me
- A "blocked" result can be fake: the first vulnerable-image test exited 1 because the
  *build* failed and there was no image to scan. The proof scripts now stop on a build error.
- `git apply -R` failed to revert the planted Sonar patch because of CRLF line endings. Now
  the script backs up the file and copies it back.

### Questions I still have
- The deploy job rebuilds the image, and `apt-get upgrade` can make it differ from the one
  Phase 1 scanned. Phase 5 should build once and promote the same digest. How?
- How do I make Phase 1–3 run as one pipeline with `needs:` (Phase 5) without losing the
  per-gate summaries?

### One thing I could explain to someone right now
A gate you've never seen fail isn't a gate. Each one here has a script that feeds it a
known-bad input and checks it blocks, and a known-good input and checks it passes.

---

*Add a new session entry each time you work on this project.*
