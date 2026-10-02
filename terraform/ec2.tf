# Latest Amazon Linux 2023 (x86_64, matches the amd64 image CI builds).
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  associate_public_ip_address = true
  monitoring                  = false # detailed monitoring is billed per metric

  # Installs Docker and /usr/local/bin/deploy-app. The first container starts
  # when CI runs the deploy job (SSM Run Command), not at boot.
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    region   = data.aws_region.current.region
    registry = split("/", aws_ecr_repository.app.repository_url)[0]
    repo_url = aws_ecr_repository.app.repository_url
    app_port = var.app_port
  })
  user_data_replace_on_change = true

  # IMDSv2 only: blocks the SSRF-to-credentials trick that works against IMDSv1.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project}-app"
  }
}
