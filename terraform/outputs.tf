# The runbook copies these into GitHub repo variables (gh variable set ...).

output "ecr_repository_url" {
  description = "Push target for the app image."
  value       = aws_ecr_repository.app.repository_url
}

output "instance_id" {
  description = "EC2 instance CI deploys to via SSM Run Command."
  value       = aws_instance.app.id
}

output "app_url" {
  description = "Health check URL once the first deploy has run."
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}/health"
}

output "github_deploy_role_arn" {
  description = "Role GitHub Actions assumes through OIDC."
  value       = aws_iam_role.github_deploy.arn
}

output "aws_region" {
  value = data.aws_region.current.region
}
