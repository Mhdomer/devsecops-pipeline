# Phase 4 — Terraform Infra + EC2 Deploy

## Goal

Use Terraform to provision AWS infrastructure from scratch (ECR + EC2 + Security
Group), push the Docker image to ECR, and deploy the container to EC2 — all
triggered automatically after all security gates pass.

## Why this matters (interview story)

Anyone can deploy manually. What DevSecOps engineers do is make the infrastructure
**reproducible, auditable, and version-controlled**. Terraform means your entire
AWS environment is a set of text files in git — you can destroy and rebuild it
identically in minutes. Combined with the security gates, the story becomes:
"infrastructure that only deploys clean, scanned code, automatically."

## What we're building

```
All security gates pass (Trivy + SonarQube + ZAP)
        │
        ▼
Terraform applies infra (if changed)
  ├── ECR repository created
  ├── EC2 instance provisioned
  └── Security group: port 5000 open, port 22 restricted
        │
        ▼
Docker image tagged + pushed to ECR
        │
        ▼
EC2 pulls image from ECR and runs container
        │
        ▼
App live at http://<ec2-public-ip>:5000
```

## AWS resources provisioned by Terraform

| Resource | Purpose |
|----------|---------|
| `aws_ecr_repository` | Private container registry for the image |
| `aws_instance` (EC2) | Runs the Docker container |
| `aws_security_group` | Firewall — port 5000 open, SSH restricted to your IP |
| `aws_iam_role` | EC2 role to pull from ECR without hardcoded credentials |
| `aws_iam_instance_profile` | Attaches IAM role to the EC2 instance |

## Files created in this phase

```
├── terraform/
│   ├── main.tf             # Provider config + backend
│   ├── variables.tf        # Input variables (region, instance type, etc.)
│   ├── outputs.tf          # Outputs (EC2 public IP, ECR URL)
│   ├── ecr.tf              # ECR repository
│   ├── ec2.tf              # EC2 instance + user_data script
│   ├── iam.tf              # IAM role for EC2 → ECR access
│   └── security_group.tf   # Security group rules
├── .github/
│   └── workflows/
│       └── phase-4-deploy.yml   # GitHub Actions: Terraform + deploy
```

## Terraform state

Terraform tracks what it has provisioned in a **state file**. We store it remotely
in an **S3 bucket** so multiple runs (local and CI) share the same view of infra.

```hcl
terraform {
  backend "s3" {
    bucket = "devsecops-tfstate"
    key    = "pipeline/terraform.tfstate"
    region = "us-east-1"
  }
}
```

**Never commit the state file to git.** It contains sensitive resource IDs.

## Security design decisions

| Decision | Reason |
|----------|--------|
| EC2 pulls image using IAM role | No AWS credentials stored on the instance |
| SSH restricted to your IP in security group | No open SSH to the world |
| Port 22 closed in production | App-only access; SSH only during setup |
| ECR image scanning enabled | AWS runs its own Trivy-equivalent on push |
| Secrets in GitHub Actions secrets | No credentials in code or Terraform files |

## Deploy script (what runs on EC2)

The EC2 `user_data` script runs on first boot:

```bash
#!/bin/bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ecr-url>
docker pull <ecr-url>/devsecops-demo:latest
docker run -d -p 5000:5000 devsecops-demo:latest
```

## GitHub Actions secrets required

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user key (CI only — limited permissions) |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret |
| `AWS_REGION` | `us-east-1` |

## Checkpoint questions for Phase 4

1. What is Terraform state and why must it be stored remotely in a team/CI context?
2. What is the security risk of storing AWS credentials on the EC2 instance vs using an IAM role?
3. What does `terraform plan` do and why do you run it before `terraform apply`?
4. What is ECR and how is it different from Docker Hub?
5. Why does the security group restrict SSH to your IP rather than `0.0.0.0/0`?

## Success criteria for Phase 4

- [ ] `terraform init` and `terraform plan` run clean locally
- [ ] `terraform apply` provisions ECR + EC2 in AWS
- [ ] Docker image pushed to ECR after security gates pass
- [ ] EC2 pulls and runs the image on first boot
- [ ] App reachable at `http://<ec2-public-ip>:5000/health`
- [ ] `terraform destroy` tears everything down cleanly (cost control)
- [ ] No AWS credentials hardcoded anywhere in the repo

## Previous phase

[Phase 3 — OWASP ZAP DAST Gate](phase-3-owasp-zap-dast.md)

## Next phase

[Phase 5 — Full Pipeline Integration + Polish](phase-5-integration.md)
