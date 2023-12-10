resource "aws_iam_role" "GhaSponsorDeploy" {
  name                 = "GhaSponsorDeploy"
  assume_role_policy   = data.aws_iam_policy_document.GhaSponsorDeploy-trust.json
  max_session_duration = 3600 * 4
}

data "aws_iam_policy_document" "GhaSponsorDeploy-trust" {
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
      values = [
        "repo:ruby-no-kai/sponsor-app:environment:production",
      ]
    }
  }
}

resource "aws_iam_role_policy" "GhaSponsorDeploy" {
  role   = aws_iam_role.GhaSponsorDeploy.id
  name   = "GhaSponsorDeploy"
  policy = data.aws_iam_policy_document.GhaSponsorDeploy.json
}

data "aws_iam_policy_document" "GhaSponsorDeploy" {
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
    resources = ["arn:aws:ecs:us-west-2:${local.aws_account_id}:service/*/sponsor-*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "apprunner:DescribeService",
      "apprunner:UpdateService",
      "apprunner:ListOperations",
      "apprunner:ListTagsForResource",
    ]
    resources = [
      aws_apprunner_service.prd.arn,
    ]
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
    resources = [
      aws_iam_role.SponsorApp.arn,
      aws_iam_role.EcsExecSponsorApp.arn,
      aws_iam_role.app-runner-access.arn,
    ]
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

  # Terraform
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
    resources = [
      aws_iam_role.SponsorApp.arn,
      aws_iam_role.app-runner-access.arn,
    ]
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
