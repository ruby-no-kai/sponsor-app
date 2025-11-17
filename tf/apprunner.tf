# Note: apprunner_deploy.rb script handling is deferred
# Image identifier and environment variables should be managed outside Terraform
# Using lifecycle ignore_changes to prevent Terraform from reverting manual updates

resource "aws_apprunner_service" "main" {
  count = var.enable_apprunner ? 1 : 0

  service_name = var.service_name

  source_configuration {
    image_repository {
      image_configuration {
        port = "3000"
        runtime_environment_variables = {}
        runtime_environment_secrets = {}
      }
      image_identifier      = "${var.enable_shared_resources ? aws_ecr_repository.app[0].repository_url : "005216166247.dkr.ecr.us-west-2.amazonaws.com/sponsor-app"}:latest"
      image_repository_type = "ECR"
    }
    authentication_configuration {
      access_role_arn = aws_iam_role.app-runner-access[0].arn
    }
    auto_deployments_enabled = false
  }

  instance_configuration {
    cpu    = "256"
    memory = "512"

    instance_role_arn = aws_iam_role.SponsorApp.arn
  }

  health_check_configuration {
    protocol = "TCP"
    #path                = "/site/sha"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 5
  }

  tags = {
    Name        = var.service_name
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [
      source_configuration[0].image_repository[0].image_identifier,
      source_configuration[0].image_repository[0].image_configuration[0].runtime_environment_variables,
      source_configuration[0].image_repository[0].image_configuration[0].runtime_environment_secrets,
    ]
  }
}

resource "aws_iam_role" "app-runner-access" {
  count = var.enable_apprunner ? 1 : 0

  name               = var.iam_apprunner_access_name
  description        = "${var.environment} tf/iam.tf"
  assume_role_policy = data.aws_iam_policy_document.app-runner-access-trust[0].json
}

data "aws_iam_policy_document" "app-runner-access-trust" {
  count = var.enable_apprunner ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "build.apprunner.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role_policy" "app-runner-access" {
  count = var.enable_apprunner ? 1 : 0

  role   = aws_iam_role.app-runner-access[0].name
  policy = data.aws_iam_policy_document.app-runner-access[0].json
}

data "aws_iam_policy_document" "app-runner-access" {
  count = var.enable_apprunner ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "sts:GetServiceBearerToken",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
    ]
    resources = [
      var.enable_shared_resources ? aws_ecr_repository.app[0].arn : "arn:aws:ecr:us-west-2:005216166247:repository/sponsor-app",
    ]
  }
}
