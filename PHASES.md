# DevSecOps Pipeline — Project Phases

## Overview

A production-style CI/CD pipeline with automated security gates, built on:
- **App:** Python / Flask
- **Containers:** Docker (multi-stage, hardened)
- **Security:** Trivy · SonarQube · OWASP ZAP
- **CI/CD:** GitHub Actions
- **Infra:** Terraform → AWS EC2 + ECR

Each phase has its own plan doc (`docs/phase-N-*.md`) written before any code.
Start with [docs/engineering-log.md](docs/engineering-log.md): architecture, how to run it, and the build history.

---

## Phases

| # | Phase | Status | Doc |
|---|-------|--------|-----|
| 1 | Docker + Trivy (container scanning gate) | 🟢 Green in CI (2026-10-02); block-in-CI PR pending | [phase-1-docker-trivy.md](docs/phase-1-docker-trivy.md) |
| 2 | SonarQube SAST gate | 🟢 Green in CI, SonarCloud gate passed; block-in-CI PR pending | [phase-2-sonarqube-sast.md](docs/phase-2-sonarqube-sast.md) |
| 3 | OWASP ZAP DAST gate | 🟢 Green in CI; block-in-CI PR pending | [phase-3-owasp-zap-dast.md](docs/phase-3-owasp-zap-dast.md) |
| 4 | Terraform infra + EC2 deploy | 🔧 Terraform checks green in CI; deploy pending AWS funding | [phase-4-terraform-deploy.md](docs/phase-4-terraform-deploy.md) |
| 5 | Full pipeline integration + polish | 🔲 Not started | [phase-5-integration.md](docs/phase-5-integration.md) |

A phase turns ✅ only after the gate is proven in GitHub Actions both ways (clean change
passes, planted problem fails). Local proofs: `scripts/prove-*-gate.sh`, output in
`docs/evidence/`. AWS steps: `docs/aws-runbook.md`.

---

## Status Key

| Symbol | Meaning |
|--------|---------|
| 🔲 | Not started |
| 🔄 | In progress |
| 🧪 | Gate proven locally both ways; CI run still needed |
| 🟢 | Passes in CI and blocks locally; still needs a red CI run to show it blocking there |
| 🔧 | Built and tested offline; needs AWS to finish |
| ✅ | Complete |

---

## Success Criteria (overall)

- [x] A git push triggers the full pipeline automatically (first green run 2026-10-02, commit `2931a4d`)
- [ ] Trivy blocks deploy if CRITICAL CVEs are found in the image (proven locally)
- [ ] SonarQube blocks deploy if quality/security gate fails (proven locally)
- [ ] OWASP ZAP blocks deploy if HIGH web vulnerabilities or missing security headers are found (proven locally)
- [ ] Terraform provisions EC2 + ECR from scratch with one command
- [ ] App is live on EC2 behind a security group, reachable via public IP
- [ ] All gates are enforced — a deliberately broken image/code fails the pipeline
