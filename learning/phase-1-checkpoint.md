# Phase 1 Checkpoint — Docker + Trivy

Date: 2026-05-07  
Status: In progress (Q1–Q4 reviewed, Q3 has open follow-up)

---

## Q1 — What is a multi-stage Docker build and why does it matter?

**Your answer:**  
Multi-stage allows building in separate stages instead of compiling all dependencies and cache into one single layer. We only copy the compiled output from the build stage into the final image.

**Reviewed:**  
Correct on size/resource efficiency. The deeper security reason you should add to your answer: the builder stage contains tools like `pip`, `gcc`, `curl` — these are attack surface at runtime. An attacker who compromises the app could use those tools to escalate. The final image has none of them. **Size is a bonus; reduced attack surface is the real win.**

**One-liner to memorise:**  
> Multi-stage = build tools stay in the builder, attack surface stays out of production.

---

## Q2 — Why run the container as a non-root user?

**Your answer:**  
Docker containers default to UID 0 (same as host root). If an attacker escapes the container, they land on the host as root.

**Reviewed:**  
Best answer of the five. Exactly right mechanism. The technical term for what you described is a **container breakout**. Use that phrase in interviews — it signals you understand the threat model, not just the config.

**One-liner to memorise:**  
> Non-root = container breakout doesn't hand the attacker UID 0 on the host.

---

## Q3 — What is a CVE and how does Trivy actually scan?

**Your answer:**  
CVE = Common Vulnerability and Exposure — a database that maps discovered vulnerabilities to serial numbers. Trivy goes through the codebase and checks each package against the CVE database.

**Reviewed:**  
CVE definition is correct. "Goes through the codebase" is **wrong** for image scanning — Trivy reads **package manifests** (the metadata of installed OS packages from `dpkg`/`apk`, and Python packages from pip's metadata directory inside the image layers). It does a version lookup against vulnerability databases (NVD, GitHub Advisory DB). It is not parsing your source code.  

This distinction matters: Trivy is fast because it's metadata lookups, not code analysis. It also means it **cannot** find vulnerabilities in your own logic — that's what SonarQube does in Phase 2.

**One-liner to memorise:**  
> Trivy reads package manifests, not source code. Fast metadata lookup, not static analysis.

### Follow-up — CRITICAL vs HIGH severity

**Your answer:**  
CRITICAL = no conditions needed, like RCE with no user interaction. HIGH = needs network access or something to help the exploit.

**Reviewed:**  
CRITICAL is correct. HIGH is slightly off — HIGH can still be network-accessible. The real distinction is that HIGH has **at least one friction factor in the attack chain**:
- Requires user interaction (click a link, open a file)
- Requires some privileges/auth first
- Only partial CIA impact (not full compromise)
- Higher attack complexity

CRITICAL = attacker does it alone, remotely, right now.  
HIGH = attacker does serious damage but needs one thing to go right first.

Trivy maps these to CVSS scores: CRITICAL = 9.0–10.0, HIGH = 7.0–8.9.

**One-liner to memorise:**  
> CRITICAL = no preconditions, full impact. HIGH = one friction factor in the chain.

---

## Q4 — What does `exit-code: '1'` do in the Trivy GitHub Action?

**Your answer:**  
A condition that stops the pipeline if a CVE is found.

**Reviewed:**  
Right outcome, wrong mechanism. Every process exits with a number: `0` = success, non-zero = failure. GitHub Actions marks a step as **failed** when its process exits non-zero. `exit-code: '1'` tells Trivy: "exit with code 1 if you find CVEs matching the severity filter." That exit code fails the step, which blocks all downstream jobs.  

Without it (`exit-code: '0'`), Trivy always exits `0` — it reports 50 CRITICAL findings but the pipeline happily continues. The report is cosmetic; the exit code is the actual gate.

**One-liner to memorise:**  
> `exit-code: '1'` turns a Trivy *report* into a Trivy *gate*. Without it, findings are ignored by the pipeline.

---

## Q5 — What does `.dockerignore` do?

**Your answer:**  
Like any `.ignore` file — tells Docker to exclude `.env` and test files from the build.

**Reviewed:**  
Correct. One thing to add: it controls the **build context** — the set of files sent to the Docker daemon before the build starts. Without it, your entire repo (`.git` history, `terraform/` state, credentials) gets sent over and can end up in intermediate image layers. Even if the final stage doesn't copy them, they may still be extractable from earlier layers.

**One-liner to memorise:**  
> `.dockerignore` controls build context — files not listed here get sent to the daemon and can leak into intermediate layers.

---

## Status

All 5 checkpoint questions answered and reviewed. ✅  
Ready to implement Phase 1.
