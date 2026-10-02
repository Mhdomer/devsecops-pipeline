# Private registry for the app image.
resource "aws_ecr_repository" "app" {
  name = var.project

  # A tag always means the same image: CI pushes by commit SHA and can never
  # overwrite an image that already passed the gates.
  image_tag_mutability = "IMMUTABLE"

  # A second scan on AWS's side, on top of the Trivy gate in CI.
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  # Lets `terraform destroy` remove the repo even with images in it (teardown).
  force_delete = true
}

# Keep storage cost flat: only the 10 newest images are kept.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 10 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
