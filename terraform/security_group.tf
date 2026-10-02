# Default VPC: no NAT gateway, no load balancer, nothing to pay for in networking
# beyond the instance's public IPv4 address.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

resource "aws_security_group" "app" {
  name        = "${var.project}-app"
  description = "App port in, HTTPS out. No SSH: shell access goes through SSM Session Manager."
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  for_each = toset(var.app_ingress_cidrs)

  security_group_id = aws_security_group.app.id
  description       = "App port"
  ip_protocol       = "tcp"
  from_port         = var.app_port
  to_port           = var.app_port
  cidr_ipv4         = each.value
}

# HTTPS only: ECR, S3 (image layers), SSM and the Amazon Linux package repos all
# use 443. DNS and NTP go to the VPC resolver / link-local addresses, which
# security groups do not filter.
# Accepted risk (Trivy AWS-0104): narrowing this needs VPC interface endpoints
# for ECR/SSM (~$7/month each), which this zero-NAT, low-cost design avoids.
#trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS out"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}
