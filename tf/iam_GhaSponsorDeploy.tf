resource "aws_iam_role" "GhaSponsorDeploy" {
  count                = var.enable_shared_resources ? 1 : 0
  name                 = "GhaSponsorDeploy"
  description          = null
  assume_role_policy   = data.aws_iam_policy_document.GhaSponsorDeploy-trust[0].json
  max_session_duration = 3600 * 4
}

data "aws_iam_policy_document" "GhaSponsorDeploy-trust" {
  count = var.enable_shared_resources ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github-actions.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_actions_sub]
    }
  }
}

resource "aws_iam_role_policy" "GhaSponsorDeploy" {
  count  = var.enable_shared_resources ? 1 : 0
  role   = aws_iam_role.GhaSponsorDeploy[0].id
  name   = "GhaSponsorDeploy"
  policy = data.aws_iam_policy_document.GhaSponsorDeploy[0].json
}

data "aws_iam_policy_document" "GhaSponsorDeploy" {
  count = var.enable_shared_resources ? 1 : 0
  statement {
    effect = "Deny"
    actions = [
      "ecs:TagResource",
      "ecs:UntagResource",
    ]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "aws:ResourceTag/Project"
      values   = ["sponsor-app"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "ecs:*",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = ["sponsor-app"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "ecs:*",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = ["sponsor-app"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
    ]
    resources = ["arn:aws:ecs:us-west-2:${data.aws_caller_identity.current.account_id}:service/*/sponsor-*"]
  }

  # AppRunner permissions (only when AppRunner is enabled)
  dynamic "statement" {
    for_each = var.enable_apprunner ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "apprunner:DescribeService",
        "apprunner:UpdateService",
        "apprunner:ListOperations",
        "apprunner:ListTagsForResource",
      ]
      resources = [
        aws_apprunner_service.main[0].arn,
      ]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "apprunner:ListServices",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = concat(
      [
        aws_iam_role.SponsorApp.arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/EcsExecSponsorApp",
      ],
      var.enable_apprunner ? [aws_iam_role.app-runner-access[0].arn] : []
    )
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:PutMetricAlarm",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "ecs:Describe*",
      "ecs:List*",
    ]
    resources = ["*"]
  }

  # DynamoDB permissions for Terraform state locking (legacy, may not be needed with use_lockfile)
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [data.aws_dynamodb_table.rk-terraform.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:Get*",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
    ]
    resources = concat(
      [aws_iam_role.SponsorApp.arn],
      var.enable_apprunner ? [aws_iam_role.app-runner-access[0].arn] : []
    )
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = ["arn:aws:s3:::rk-infra"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["arn:aws:s3:::rk-infra/terraform/sponsor-app.tfstate"]
  }
}
