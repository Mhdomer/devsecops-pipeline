locals {
  ecr_auth_statement = {
    Sid      = "EcrLogin"
    Effect   = "Allow"
    Action   = ["ecr:GetAuthorizationToken"]
    Resource = "*" # this action has no resource-level scoping
  }
}

# ── EC2 instance role: pull this one repo, be reachable by SSM ──────────────
resource "aws_iam_role" "ec2" {
  name = "${var.project}-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_ecr_pull" {
  name = "ecr-pull-app-repo"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      local.ecr_auth_statement,
      {
        Sid    = "PullAppImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = aws_ecr_repository.app.arn
      },
    ]
  })
}

# Session Manager shell + Run Command (how CI deploys). Replaces SSH entirely.
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-ec2"
  role = aws_iam_role.ec2.name
}

# ── GitHub Actions OIDC: short-lived credentials, no access keys in GitHub ──
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_provider_arn = (var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
  : data.aws_iam_openid_connect_provider.github[0].arn)
}

# Deploy role: only workflow runs on this repo's deploy branch can assume it,
# and it can only push to this repo's ECR and run a command on this instance.
# It cannot run Terraform: infra changes are applied by a human (runbook).
resource "aws_iam_role" "github_deploy" {
  name                 = "${var.project}-github-deploy"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/${var.github_deploy_branch}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_deploy" {
  name = "push-image-and-deploy"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      local.ecr_auth_statement,
      {
        Sid    = "PushAppImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "RunDeployCommandOnAppInstance"
        Effect = "Allow"
        Action = ["ssm:SendCommand"]
        Resource = [
          aws_instance.app.arn,
          "arn:aws:ssm:${data.aws_region.current.region}::document/AWS-RunShellScript",
        ]
      },
      {
        Sid      = "ReadDeployCommandResult"
        Effect   = "Allow"
        Action   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"]
        Resource = "*" # these actions have no resource-level scoping
      },
    ]
  })
}
