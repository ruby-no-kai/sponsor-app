resource "aws_iam_role" "SponsorApp" {
  name                 = var.iam_role_prefix
  description          = var.iam_role_prefix
  assume_role_policy   = data.aws_iam_policy_document.SponsorApp-trust.json
  max_session_duration = 43200
}

data "aws_iam_policy_document" "SponsorApp-trust" {
  # Service principal trust for AppRunner and ECS (prd)
  dynamic "statement" {
    for_each = var.enable_amc_oidc ? [] : [1]
    content {
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals {
        type = "Service"
        identifiers = [
          "ecs-tasks.amazonaws.com",
          "tasks.apprunner.amazonaws.com",
        ]
      }
    }
  }

  # OIDC trust for AMC (dev)
  dynamic "statement" {
    for_each = var.enable_amc_oidc ? [1] : []
    content {
      effect  = "Allow"
      actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]
      principals {
        type = "Federated"
        identifiers = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/amc.rubykaigi.net",
        ]
      }
      condition {
        test     = "StringLike"
        variable = "amc.rubykaigi.net:sub"
        values   = ["${data.aws_caller_identity.current.account_id}:${var.iam_role_prefix}:*"]
      }
    }
  }
}

resource "aws_iam_role_policy" "SponsorApp" {
  role   = aws_iam_role.SponsorApp.name
  policy = data.aws_iam_policy_document.SponsorApp.json
}

data "aws_iam_policy_document" "SponsorApp" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    resources = [
      aws_iam_role.SponsorAppUser.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.files.arn,
      "${aws_s3_bucket.files.arn}/*",
    ]
  }

  # SQS permissions (only when enabled)
  dynamic "statement" {
    for_each = var.enable_sqs ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
      ]
      resources = [
        aws_sqs_queue.activejob[0].arn
      ]
    }
  }

  # SSM permissions for secrets defined in var.secrets
  dynamic "statement" {
    for_each = length(var.secrets) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "ssm:GetParameters",
      ]
      resources = values(var.secrets)
    }
  }

  dynamic "statement" {
    for_each = var.enable_apprunner ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
      ]
      resources = [data.aws_kms_key.usw2_ssm.arn]
    }
  }
}
