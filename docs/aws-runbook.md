# AWS Runbook — Phase 4 deploy

> **PENDING: waiting for the account to be funded.**
> Nothing in this file has been run. No AWS API call has been made for this project yet.
> Everything before step 1 was tested offline (`terraform validate`, `terraform test` with a
> mocked provider, `trivy config`).

## What gets created

13 resources, all tagged `Project=devsecops-pipeline`, `ManagedBy=terraform`:

| Resource | Notes |
|---|---|
| `aws_instance.app` | t3.micro, Amazon Linux 2023, default VPC, public IP, IMDSv2, encrypted gp3 root |
| `aws_security_group.app` + 1 ingress + 1 egress rule | in: TCP 5000 from `app_ingress_cidrs`; out: TCP 443. **No port 22** |
| `aws_ecr_repository.app` + lifecycle policy | immutable tags, scan on push, keeps 10 images |
| `aws_iam_role.ec2` + inline policy + SSM attachment + instance profile | pull from this repo only; SSM for shell and deploys |
| `aws_iam_openid_connect_provider.github` | skipped if the account already has one (step 1) |
| `aws_iam_role.github_deploy` + inline policy | OIDC, `main` branch of this repo only; push to this repo + SSM on this instance |

Plus, created by hand in step 2: one S3 bucket for Terraform state.

## Cost estimate (us-east-1, on-demand)

| Item | Rate | Per day | Per month if left running |
|---|---|---|---|
| t3.micro | $0.0104/hr | $0.25 | $7.59 |
| Public IPv4 address | $0.005/hr | $0.12 | $3.65 |
| EBS gp3, 8 GiB root | $0.08/GB-month | $0.02 | $0.64 |
| ECR storage (≤10 images × ~60 MB) | $0.10/GB-month | <$0.01 | ~$0.06 |
| S3 state bucket | a few KB | ~$0 | ~$0 |
| SSM Session Manager / Run Command | free | $0 | $0 |
| **Total** | | **~$0.40** | **~$12** |

A demo session (apply, deploy, show it, destroy within 2 hours) costs about **$0.05**.
New accounts may have free-tier credits that cover this; check Billing > Free Tier.
Prices change: confirm on the EC2 and VPC pricing pages before step 3.

What would make it cost more, and is deliberately absent: NAT gateway (~$32/month), load
balancer (~$16/month), VPC interface endpoints (~$7/month each), detailed monitoring.

---

## Step 0 — Before anything (you, in the console)

1. Set a budget alarm: Billing > Budgets > Create budget > "Zero spend" or a $5 monthly
   cost budget, email to you. (The first two budgets are free.)
2. Have the AWS CLI configured with your own admin profile (not the CI role):
   ```bash
   aws sts get-caller-identity          # confirm account and identity
   export AWS_REGION=us-east-1
   ```
3. Phase 1–3 workflows must be green on `main` (the deploy job checks this), which needs
   `SONAR_TOKEN` set.

## Step 1 — Read-only pre-checks

```bash
# Default VPC must exist (the config uses it to avoid NAT costs)
aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[].VpcId'

# Is there already a GitHub OIDC provider? (Your FYP pipeline may have created one.)
aws iam list-open-id-connect-providers
```
- Empty VPC list: create one with `aws ec2 create-default-vpc`.
- If an ARN ending in `token.actions.githubusercontent.com` is listed, set
  `create_github_oidc_provider = false` in step 3 (only one per account is allowed).

## Step 2 — State bucket (one time)

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="devsecops-pipeline-tfstate-$ACCOUNT_ID"

aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION"
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging 'TagSet=[{Key=Project,Value=devsecops-pipeline}]'

cd terraform
cp backend.hcl.example backend.hcl     # gitignored
sed -i "s/<account-id>/$ACCOUNT_ID/" backend.hcl
```
(Outside us-east-1, `create-bucket` also needs
`--create-bucket-configuration LocationConstraint=$AWS_REGION`.)

## Step 3 — Plan and apply

```bash
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan                    # add -var create_github_oidc_provider=false if step 1 found one
```
Check the plan before applying:
- `Plan: 13 to add, 0 to change, 0 to destroy` (12 if reusing the OIDC provider)
- `instance_type = "t3.micro"`, no ingress rule on port 22, egress only 443
- trust policy `sub` = `repo:Mhdomer/devsecops-pipeline:ref:refs/heads/main`

```bash
terraform apply tfplan
terraform output
```

## Step 4 — Wire GitHub to the new infra

```bash
gh variable set AWS_REGION          --body "$(terraform output -raw aws_region)"
gh variable set ECR_REPOSITORY_URL  --body "$(terraform output -raw ecr_repository_url)"
gh variable set EC2_INSTANCE_ID     --body "$(terraform output -raw instance_id)"
gh variable set APP_URL             --body "$(terraform output -raw app_url)"
gh variable set AWS_DEPLOY_ROLE_ARN --body "$(terraform output -raw github_deploy_role_arn)"
gh variable set AWS_DEPLOY_ENABLED  --body true
```
These are variables, not secrets: none of them grants access on its own. The role can only be
assumed by a workflow on `main` of this repo.

## Step 5 — Wait for the instance

```bash
# user_data installs Docker; the SSM agent registers within ~2 minutes of boot
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$(terraform output -raw instance_id)" \
  --query 'InstanceInformationList[].PingStatus'          # want ["Online"]
```

## Step 6 — First deploy

```bash
gh workflow run phase-4-deploy.yml --ref main
gh run watch
```
The deploy job: checks the three gate workflows passed for this commit → builds → Trivy gate
again → assumes the role via OIDC → pushes `:<sha>` to ECR → SSM runs `deploy-app <sha>` →
smoke-tests `APP_URL`.

## Step 7 — Verify

```bash
curl -i "$(terraform output -raw app_url)"            # 200, {"status":"healthy"}, security headers present

# AWS's own scan of the pushed image
aws ecr describe-image-scan-findings --repository-name devsecops-pipeline \
  --image-id imageTag=$(git rev-parse HEAD) --query 'imageScanFindings.findingSeverityCounts'

# Shell without SSH
aws ssm start-session --target "$(terraform output -raw instance_id)"   # needs the Session Manager plugin

# Port 22 really is closed
nc -vz -w 5 "$(terraform output -raw app_url | sed -E 's#http://([^:]+):.*#\1#')" 22   # should time out
```
Screenshot the green pipeline run and the curl output for the README (Phase 5).

## Step 8 — Teardown (same day, unless you want it running)

```bash
gh variable set AWS_DEPLOY_ENABLED --body false
terraform destroy                                   # removes all 13 resources, ECR images included

# Nothing tagged for this project should remain except the state bucket
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=devsecops-pipeline --query 'ResourceTagMappingList[].ResourceARN'
```
Keep the state bucket if you'll deploy again (it costs ~nothing). To remove it too, empty
every object version first (Console > S3 > bucket > Empty), then
`aws s3api delete-bucket --bucket "$BUCKET"`.

If `create_github_oidc_provider = false` was used, destroy leaves the shared provider alone.

## If something goes wrong

| Symptom | Likely cause |
|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Workflow not on `main`, or the OIDC provider ARN in the trust policy is wrong |
| SSM `InvalidInstanceId` | Agent not registered yet (step 5), or no outbound 443 |
| `deploy-app: refusing tag` | Something other than a 40-char commit SHA was passed |
| `ImageTagAlreadyExistsException` | Same commit deployed twice; tags are immutable. Re-run the SSM step only, or push a new commit |
| Smoke test fails, SSM succeeded | `app_ingress_cidrs` doesn't include the GitHub runner (only an issue if you locked it to your IP) |
