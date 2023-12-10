data "external" "apprunner-deploy" {
  program = ["ruby", "${path.module}/apprunner_deploy.rb"]
}

resource "aws_apprunner_service" "prd" {
  service_name = "sponsor-app"

  source_configuration {
    image_repository {
      image_configuration {
        port = "3000"
        runtime_environment_variables = merge(jsondecode(data.external.apprunner-deploy.result.runtime_environment_variables), {
        })
        runtime_environment_secrets = jsondecode(data.external.apprunner-deploy.result.runtime_environment_secrets)
      }
      image_identifier      = data.external.apprunner-deploy.result.image_identifier
      image_repository_type = "ECR"
    }
    authentication_configuration {
      access_role_arn = aws_iam_role.app-runner-access.arn
    }
    auto_deployments_enabled = false
  }

  instance_configuration {
    cpu    = "512"
    memory = "1024"

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
    Name        = "sponsor-app"
    Environment = "production"
  }
}

resource "aws_iam_role" "app-runner-access" {
  name               = "AppraSponsorApp"
  description        = "prd tf/iam.tf"
  assume_role_policy = data.aws_iam_policy_document.app-runner-access-trust.json
}

data "aws_iam_policy_document" "app-runner-access-trust" {
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
  role   = aws_iam_role.app-runner-access.name
  policy = data.aws_iam_policy_document.app-runner-access.json
}

data "aws_iam_policy_document" "app-runner-access" {
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
      aws_ecr_repository.app.arn,
    ]
  }
}

