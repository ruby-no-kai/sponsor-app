resource "aws_iam_role" "EcsExecSponsorApp" {
  name                 = "EcsExecSponsorApp"
  description          = "EcsExecSponsorApp"
  assume_role_policy   = data.aws_iam_policy_document.EcsExecSponsorApp-trust.json
  max_session_duration = 43200
}

data "aws_iam_policy_document" "EcsExecSponsorApp-trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "EcsExecSponsorApp" {
  role   = aws_iam_role.EcsExecSponsorApp.name
  policy = data.aws_iam_policy_document.EcsExecSponsorApp.json
}

data "aws_iam_policy_document" "EcsExecSponsorApp" {
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
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
    ]
    resources = ["arn:aws:ssm:*:${local.aws_account_id}:parameter/sponsor-app/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [data.aws_kms_key.usw2_ssm.arn]
  }
}


