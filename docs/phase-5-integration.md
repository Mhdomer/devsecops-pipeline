# Phase 5 — Full Pipeline Integration + Polish

## Goal

Merge all four phase workflows into a single, production-style GitHub Actions
pipeline. Add a README that tells the project story clearly for recruiters and
interviewers. Add a `LEARNING.md` journal and final interview prep.

## Why this matters (interview story)

Phases 1–4 are working parts. Phase 5 makes it a *system*. The gates run in the
right order, failures in early gates skip later ones, the deploy only happens when
everything passes. This is what a real DevSecOps pipeline looks like — not four
separate scripts, but one coordinated workflow with clear job dependencies.

## What we're building

```
Push to main
    │
    ▼
┌─────────────┐
│  Unit Tests │
└──────┬──────┘
       │ passes
       ▼
┌─────────────────────┐
│  Docker Build       │
└──────┬──────────────┘
       │ passes
       ▼
┌──────────────────────────────────────────┐
│  Security Gates (parallel)               │
│  ┌────────────┐  ┌──────────────────┐   │
│  │  Trivy     │  │  SonarQube SAST  │   │
│  └────────────┘  └──────────────────┘   │
└──────┬───────────────────────────────────┘
       │ both pass
       ▼
┌─────────────────────┐
│  OWASP ZAP DAST     │
└──────┬──────────────┘
       │ passes
       ▼
┌─────────────────────┐
│  Terraform Apply    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Deploy to EC2      │
└─────────────────────┘
```

## Files created in this phase

```
├── .github/
│   └── workflows/
│       └── pipeline.yml        # The single unified pipeline
├── README.md                   # Project story for recruiters/GitHub
├── LEARNING.md                 # Session journal (your personal record)
```

## Unified pipeline design decisions

| Decision | Reason |
|----------|--------|
| Trivy + SonarQube run in parallel | They're independent — no reason to run sequentially |
| ZAP runs after both pass | ZAP needs the image (Trivy dependency) and clean code (SonarQube dependency) |
| Deploy only on `main` branch pushes | PRs run all gates but don't deploy |
| `terraform apply` only if plan shows changes | Avoid unnecessary applies |
| Job summaries written to GitHub step summary | Results visible without reading logs |

## README structure (what recruiters need to see)

```
# DevSecOps Pipeline

## What this is
## Architecture diagram
## Security gates (what each one does and why)
## How to run it locally
## Pipeline in action (screenshot or gif of a passing + failing run)
## Tech stack
```

## Polish checklist

- [ ] Pipeline badge in README (shows pass/fail status)
- [ ] GitHub Security tab populated with Trivy SARIF results
- [ ] ZAP HTML report downloadable from GitHub Actions artifacts
- [ ] SonarCloud dashboard linked in README
- [ ] `terraform destroy` documented — prevents runaway AWS costs
- [ ] `.env.example` file shows what env vars are needed (no real values)

## Final interview prep

After Phase 5, you should be able to:

- Draw the full pipeline from memory (no notes)
- Explain what each gate catches and what it *cannot* catch
- Describe a scenario where the pipeline blocked a real deployment
- Explain how the Terraform state is managed and why
- Explain the IAM role vs hardcoded credentials trade-off
- Walk through the Dockerfile line by line and justify every decision
- Explain container breakout and how the non-root user mitigates it

## Checkpoint questions for Phase 5

1. Why do Trivy and SonarQube run in parallel but ZAP runs after both?
2. What is a GitHub Actions job dependency and how do you express it?
3. What is the difference between a pipeline that *reports* security findings and one that *gates* on them?
4. If a recruiter asks "walk me through your pipeline" — what is the one-minute answer?
5. What would you add to this pipeline if you had another week?

## Success criteria for Phase 5

- [ ] Single `pipeline.yml` replaces all four phase workflows
- [ ] A push with a clean image and code deploys end-to-end automatically
- [ ] A push with a vulnerable image is blocked at the Trivy gate
- [ ] A push with a security hotspot in code is blocked at SonarQube
- [ ] README tells the project story clearly — no prior context needed
- [ ] `LEARNING.md` has at least one entry per phase

## Previous phase

[Phase 4 — Terraform Infra + EC2 Deploy](phase-4-terraform-deploy.md)
