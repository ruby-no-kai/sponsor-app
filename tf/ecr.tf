resource "aws_ecr_repository" "app" {
  count = var.enable_shared_resources ? 1 : 0
  name  = "sponsor-app"
}

resource "aws_ecr_lifecycle_policy" "app" {
  count      = var.enable_shared_resources ? 1 : 0
  repository = aws_ecr_repository.app[0].name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 10
        description  = "expire old images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
