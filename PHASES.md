# DevSecOps Pipeline — Project Phases

## Overview

A production-style CI/CD pipeline with automated security gates, built on:
- **App:** Python / Flask
- **Containers:** Docker (multi-stage, hardened)
- **Security:** Trivy · SonarQube · OWASP ZAP
- **CI/CD:** GitHub Actions
- **Infra:** Terraform → AWS EC2 + ECR

Each phase has its own plan doc (`docs/phase-N-*.md`) written before any code.

---

## Phases

| # | Phase | Status | Doc |
|---|-------|--------|-----|
| 1 | Docker + Trivy (container scanning gate) | 🔄 In progress | [phase-1-docker-trivy.md](docs/phase-1-docker-trivy.md) |
| 2 | SonarQube SAST gate | 🔄 In progress | [phase-2-sonarqube-sast.md](docs/phase-2-sonarqube-sast.md) |
| 3 | OWASP ZAP DAST gate | 🔲 Not started | [phase-3-owasp-zap-dast.md](docs/phase-3-owasp-zap-dast.md) |
| 4 | Terraform infra + EC2 deploy | 🔲 Not started | [phase-4-terraform-deploy.md](docs/phase-4-terraform-deploy.md) |
| 5 | Full pipeline integration + polish | 🔲 Not started | [phase-5-integration.md](docs/phase-5-integration.md) |

---

## Status Key

| Symbol | Meaning |
|--------|---------|
| 🔲 | Not started |
| 🔄 | In progress |
| ✅ | Complete |

---

## Success Criteria (overall)

- [ ] A git push triggers the full pipeline automatically
- [ ] Trivy blocks deploy if CRITICAL CVEs are found in the image
- [ ] SonarQube blocks deploy if quality/security gate fails
- [ ] OWASP ZAP blocks deploy if HIGH/CRITICAL web vulnerabilities are found
- [ ] Terraform provisions EC2 + ECR from scratch with one command
- [ ] App is live on EC2 behind a security group, reachable via public IP
- [ ] All gates are enforced — a deliberately broken image/code fails the pipeline
