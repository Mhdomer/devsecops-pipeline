variable "aws_region" {
  description = "AWS region for every resource."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name: used for resource names and the Project tag."
  type        = string
  default     = "devsecops-pipeline"
}

variable "github_repo" {
  description = "GitHub repo (owner/name) allowed to assume the deploy role."
  type        = string
  default     = "Mhdomer/devsecops-pipeline"

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must look like owner/name."
  }
}

variable "github_deploy_branch" {
  description = "Only workflow runs on this branch can assume the deploy role."
  type        = string
  default     = "main"
}

variable "instance_type" {
  description = "EC2 instance type. Limited to small burstable types as a cost guardrail."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.nano", "t3.micro"], var.instance_type)
    error_message = "Cost guardrail: instance_type must be t3.nano or t3.micro."
  }
}

variable "app_port" {
  description = "Port the container listens on (Dockerfile EXPOSE)."
  type        = number
  default     = 5000
}

variable "app_ingress_cidrs" {
  description = "CIDRs allowed to reach the app port. Public by default (it is a demo API); set to [\"<your-ip>/32\"] to lock it down."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for c in var.app_ingress_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in app_ingress_cidrs must be a valid CIDR."
  }
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one (only one per URL is allowed per account)."
  type        = bool
  default     = true
}
