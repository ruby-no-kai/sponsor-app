resource "aws_iam_role" "EcsExecSponsorApp" {
  count                = var.enable_shared_resources ? 1 : 0
  name                 = "EcsExecSponsorApp"
  description          = "EcsExecSponsorApp"
  assume_role_policy   = data.aws_iam_policy_document.EcsExecSponsorApp-trust[0].json
  max_session_duration = 43200
}

data "aws_iam_policy_document" "EcsExecSponsorApp-trust" {
  count = var.enable_shared_resources ? 1 : 0

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
  count  = var.enable_shared_resources ? 1 : 0
  role   = aws_iam_role.EcsExecSponsorApp[0].name
  policy = data.aws_iam_policy_document.EcsExecSponsorApp[0].json
}

data "aws_iam_policy_document" "EcsExecSponsorApp" {
  count = var.enable_shared_resources ? 1 : 0
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
      aws_ecr_repository.app[0].arn,
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
    resources = ["arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/sponsor-app/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [data.aws_kms_key.usw2_ssm.arn]
  }
}
