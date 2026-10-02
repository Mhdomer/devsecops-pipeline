# DevSecOps Pipeline with Full Security Gates

[![Trivy](https://github.com/Mhdomer/devsecops-pipeline/actions/workflows/phase-1-trivy.yml/badge.svg?branch=main)](https://github.com/Mhdomer/devsecops-pipeline/actions/workflows/phase-1-trivy.yml)
[![SonarQube](https://github.com/Mhdomer/devsecops-pipeline/actions/workflows/phase-2-sonarqube.yml/badge.svg?branch=main)](https://github.com/Mhdomer/devsecops-pipeline/actions/workflows/phase-2-sonarqube.yml)
[![OWASP ZAP](https://github.com/Mhdomer/devsecops-pipeline/actions/workflows/phase-3-zap.yml/badge.svg?branch=main)](https://github.com/Mhdomer/devsecops-pipeline/actions/workflows/phase-3-zap.yml)
[![Terraform](https://github.com/Mhdomer/devsecops-pipeline/actions/workflows/phase-4-deploy.yml/badge.svg?branch=main)](https://github.com/Mhdomer/devsecops-pipeline/actions/workflows/phase-4-deploy.yml)
[![Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=Mhdomer_devsecops-pipeline&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=Mhdomer_devsecops-pipeline)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=Mhdomer_devsecops-pipeline&metric=coverage)](https://sonarcloud.io/summary/new_code?id=Mhdomer_devsecops-pipeline)

A CI/CD pipeline that **refuses to deploy** unless the code passes three automated security
gates: container scanning (Trivy), static analysis (SonarCloud) and a live dynamic scan
(OWASP ZAP). Infrastructure is Terraform for AWS (EC2 + ECR), deployed through GitHub OIDC
with no stored cloud credentials and no SSH.

The app is a deliberately small Flask JSON API. The project is the pipeline around it.

**Every gate is proven both ways:** a script feeds each one a known-good build (must pass)
and a deliberately broken one (must block). A gate you have never seen fail is not a gate.

---

## The gates

| Gate | Tool | Looks at | Blocks when |
|---|---|---|---|
| Container scan | **Trivy** | Every OS and Python package in the image | Any CRITICAL vulnerability, fixed or not |
| Static analysis | **SonarCloud** | Python, Dockerfile, workflows, shell, Terraform | The "Sonar way" quality gate fails on new code |
| Dynamic scan | **OWASP ZAP** | HTTP responses of the running container | Any High-risk alert, or a mandatory security header is missing |
| Infra checks | **Terraform + Trivy** | `terraform/` | `fmt`/`validate`/`test` fail, or a HIGH/CRITICAL misconfiguration |

What each one can't see is just as important: Trivy doesn't read our code, Sonar doesn't run
it, and ZAP's passive baseline doesn't send attack payloads. Together they cover the parts,
the code and the behaviour.

## Architecture

```mermaid
flowchart LR
    push([push / PR to main]) --> T[Unit tests]
    T --> TR{{Trivy<br/>build + scan image}}
    push --> SQ{{SonarCloud<br/>quality gate}}
    push --> Z{{ZAP<br/>scan running container}}
    push --> TF[Terraform<br/>fmt / validate / test]
    TR & SQ & Z -. all green for this commit .-> D[Deploy job<br/>manual, main only]
    D -->|OIDC, 1-hour credentials| AWS[(ECR + EC2<br/>t3.micro)]
```

The deploy job checks through the GitHub API that all three gate workflows passed for the
exact commit before it does anything. Once on AWS it can push one image to one ECR repo and
run one SSM command on one instance. It cannot change infrastructure.

```mermaid
flowchart LR
    CI[GitHub Actions] -->|docker push :commit-sha| ECR[(ECR<br/>immutable tags<br/>scan on push)]
    CI -->|ssm send-command| EC2[EC2 t3.micro<br/>IMDSv2, encrypted disk<br/>in: 5000 / out: 443<br/>no SSH]
    EC2 -->|pull with instance role| ECR
```

## Proof: each gate blocking a bad change

Each gate was tested with a draft pull request containing one deliberately broken commit.
All three were blocked by the gate they targeted. `main` stays green.

| PR | Broken on purpose | Blocked by |
|---|---|---|
| [#1](https://github.com/Mhdomer/devsecops-pipeline/pull/1) | Base image swapped for end-of-life Debian 10 | **Trivy**: 2 CRITICAL CVEs, exit 1 (SonarCloud also flags the root user and unlocked installs) |
| [#2](https://github.com/Mhdomer/devsecops-pipeline/pull/2) | Hardcoded `SECRET_KEY` and `DEBUG=True` | **SonarCloud**: quality gate failed, Security Rating C on new code. Trivy and ZAP pass, because the image itself is fine |
| [#3](https://github.com/Mhdomer/devsecops-pipeline/pull/3) | Security headers removed | **ZAP**: 4 blocking header alerts. The header unit tests fail too, so it is caught twice |

**PR #1: Trivy blocks a vulnerable base image**

![Trivy gate blocking PR #1](docs/images/pr1-trivy-gate-blocked.png)

**PR #2: SonarCloud blocks a hardcoded secret**

![SonarCloud quality gate failing on PR #2](docs/images/pr2-sonar-gate-blocked.png)

**PR #3: ZAP blocks a response without security headers**

![ZAP gate blocking PR #3](docs/images/pr3-zap-gate-blocked.png)

The same checks can be reproduced locally with `scripts/prove-*-gate.sh`; their saved output is
in [docs/evidence/](docs/evidence/).

## Security decisions worth knowing

- **Trivy blocks unfixed CVEs too.** The test image on end-of-life Debian 10 had two
  CRITICALs, both "will not fix". With `ignore-unfixed` it would have passed.
- **The Trivy gate had a hidden bug.** With `format: sarif`, `trivy-action` drops the severity
  filter, so the original "block on CRITICAL" step actually blocked on *every* CVE. The fix
  splits enforcing (table, CRITICAL) from reporting (SARIF, all severities).
- **ZAP blocks on policy, not only severity.** ZAP rates missing headers Low or Medium, so a
  "High only" gate never blocks a header-less app. The headers this API promises are listed in
  [`zap/zap-baseline.conf`](zap/zap-baseline.conf) and are mandatory.
- **Supply chain:** every action pinned to a commit SHA, the base image pinned by digest,
  every Python dependency hash-locked and installed as wheels only, Dependabot keeping pins
  current, checkout tokens not persisted.
- **Identity:** GitHub OIDC trust limited to `repo:Mhdomer/devsecops-pipeline:ref:refs/heads/main`.
  No access keys exist anywhere.
- **Runtime:** IMDSv2 required, port 22 closed (shell via SSM Session Manager), HTTPS-only
  egress, immutable image tags, deploy script accepts only a 40-character commit SHA.

All decisions with their alternatives: [docs/engineering-log.md](docs/engineering-log.md#9-decision-record).

## Status

| | |
|---|---|
| Trivy, SonarCloud, ZAP gates | ✅ Pass on `main` and proven to block in CI (draft PRs #1 to #3) |
| Terraform | ✅ `validate`, 9 `terraform test` runs (mocked provider), misconfig scan clean |
| AWS deploy | ⏸ Written and tested offline, waiting for the AWS account to be funded ([runbook](docs/aws-runbook.md)) |
| Single unified pipeline | 🔲 Phase 5 |

Live phase status: [PHASES.md](PHASES.md).

## Run it locally

Needs Docker, Python 3.11+, Trivy and Terraform. On Windows, use Git Bash for the scripts.

```bash
# The app
docker build -t devsecops-demo:local .
docker run --rm -p 5000:5000 devsecops-demo:local
curl -i http://localhost:5000/health

# Unit tests (17)
python -m venv .venv && source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install --require-hashes --only-binary :all: -r requirements-dev.txt
pytest --cov=app --cov=zap

# Prove each gate passes a good build and blocks a bad one
bash scripts/prove-trivy-gate.sh
bash scripts/prove-zap-gate.sh
SONAR_TOKEN=<token> bash scripts/prove-sonar-gate.sh   # needs a SonarQube server, see the log

# Infrastructure, fully offline
cd terraform && terraform init -backend=false && terraform validate && terraform test
```

Full instructions, including a throwaway local SonarQube: [docs/engineering-log.md § 7](docs/engineering-log.md#7-how-to-run-it).

## Repository layout

```
app/                Flask API + unit tests (security headers on every response)
Dockerfile          Multi-stage, digest-pinned, non-root, no pip at runtime
.github/workflows/  One workflow per gate + Terraform checks and the (disabled) deploy
zap/                ZAP rules (what blocks) and the pass/block decision script
scripts/            Gate runners and the prove-*-gate.sh proofs
tests/gates/        Deliberately broken inputs for the proofs (never used by the real build)
terraform/          EC2 + ECR + OIDC role, with offline tests
docs/               Engineering log, phase plans, AWS runbook, proof output, reviews
```

## Tech stack

Python 3.11 · Flask · gunicorn · Docker · GitHub Actions · Trivy · SonarCloud · OWASP ZAP ·
Terraform · AWS (EC2, ECR, IAM/OIDC, SSM, S3) · pytest · actionlint · zizmor · shellcheck

## Read more

- [Engineering log](docs/engineering-log.md): architecture, every service, how to explain it, dated build history
- [AWS runbook](docs/aws-runbook.md): deploy steps, cost (~$0.05 for a 2-hour demo), teardown
- [Phase plans](docs/): written before the code, one per phase
