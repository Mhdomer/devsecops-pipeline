# Offline tests: the AWS provider is mocked, so nothing here talks to AWS.
#   cd terraform && terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
  mock_data "aws_vpc" {
    defaults = { id = "vpc-0123456789abcdef0" }
  }
  mock_data "aws_subnets" {
    defaults = { ids = ["subnet-0123456789abcdef0"] }
  }
  mock_resource "aws_ecr_repository" {
    defaults = {
      arn            = "arn:aws:ecr:us-east-1:123456789012:repository/devsecops-pipeline"
      repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/devsecops-pipeline"
    }
  }
  mock_resource "aws_instance" {
    defaults = {
      arn       = "arn:aws:ec2:us-east-1:123456789012:instance/i-0123456789abcdef0"
      public_ip = "203.0.113.10"
    }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" }
  }
}

run "ec2_is_small_and_hardened" {
  assert {
    condition     = aws_instance.app.instance_type == "t3.micro"
    error_message = "Default instance type must be t3.micro."
  }
  assert {
    condition     = aws_instance.app.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }
  assert {
    condition     = aws_instance.app.root_block_device[0].encrypted
    error_message = "Root volume must be encrypted."
  }
  assert {
    condition     = aws_instance.app.monitoring == false
    error_message = "Detailed monitoring costs money and must stay off."
  }
  assert {
    condition     = strcontains(aws_instance.app.user_data, "^[0-9a-f]{40}$")
    error_message = "deploy-app must only accept a commit SHA as the image tag."
  }
}

run "network_has_no_ssh_and_https_only_egress" {
  assert {
    condition     = alltrue([for r in aws_vpc_security_group_ingress_rule.app : r.from_port == 5000 && r.to_port == 5000])
    error_message = "The only ingress must be the app port."
  }
  assert {
    condition     = !anytrue([for r in aws_vpc_security_group_ingress_rule.app : r.from_port <= 22 && r.to_port >= 22])
    error_message = "SSH (22) must never be open."
  }
  assert {
    condition     = aws_vpc_security_group_egress_rule.https.from_port == 443 && aws_vpc_security_group_egress_rule.https.to_port == 443
    error_message = "Egress must be HTTPS only."
  }
}

run "ecr_is_immutable_and_scanned" {
  assert {
    condition     = aws_ecr_repository.app.image_tag_mutability == "IMMUTABLE"
    error_message = "Tags must be immutable so a scanned image cannot be overwritten."
  }
  assert {
    condition     = aws_ecr_repository.app.image_scanning_configuration[0].scan_on_push
    error_message = "ECR scan on push must be on."
  }
}

run "deploy_role_trusts_only_main_of_this_repo" {
  assert {
    condition = (
      jsondecode(aws_iam_role.github_deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"]
      == "repo:Mhdomer/devsecops-pipeline:ref:refs/heads/main"
    )
    error_message = "OIDC trust must be pinned to this repo's main branch."
  }
  assert {
    condition = (
      jsondecode(aws_iam_role.github_deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"]
      == "sts.amazonaws.com"
    )
    error_message = "OIDC audience must be sts.amazonaws.com."
  }
}

run "deploy_role_is_least_privilege" {
  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.github_deploy.policy).Statement : [
        for a in s.Action : !strcontains(a, "*")
      ]
    ]))
    error_message = "No wildcard actions in the deploy policy."
  }
  assert {
    # Resource "*" is allowed only for actions AWS cannot scope to a resource.
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.github_deploy.policy).Statement :
      s.Resource != "*" || contains(["EcrLogin", "ReadDeployCommandResult"], s.Sid)
    ])
    error_message = "Only unscopable actions may use Resource \"*\"."
  }
  assert {
    condition = !anytrue([
      for s in jsondecode(aws_iam_role_policy.github_deploy.policy).Statement :
      anytrue([for a in s.Action : startswith(a, "iam:") || startswith(a, "ec2:")])
    ])
    error_message = "The deploy role must not be able to change IAM or EC2 (no Terraform from CI)."
  }
}

run "everything_is_tagged_with_the_project" {
  assert {
    condition     = local.common_tags["Project"] == "devsecops-pipeline"
    error_message = "Provider default_tags must set Project=devsecops-pipeline."
  }
}

run "reuses_existing_oidc_provider" {
  variables {
    create_github_oidc_provider = false
  }

  override_data {
    target = data.aws_iam_openid_connect_provider.github
    values = { arn = "arn:aws:iam::123456789012:oidc-provider/existing" }
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0
    error_message = "Must not create a second OIDC provider."
  }
  assert {
    condition = (
      jsondecode(aws_iam_role.github_deploy.assume_role_policy).Statement[0].Principal.Federated
      == "arn:aws:iam::123456789012:oidc-provider/existing"
    )
    error_message = "Deploy role must trust the existing provider."
  }
}

run "cost_guardrail_rejects_bigger_instances" {
  command = plan

  variables {
    instance_type = "t3.large"
  }

  expect_failures = [var.instance_type]
}

run "rejects_invalid_cidrs" {
  command = plan

  variables {
    app_ingress_cidrs = ["not-a-cidr"]
  }

  expect_failures = [var.app_ingress_cidrs]
}
