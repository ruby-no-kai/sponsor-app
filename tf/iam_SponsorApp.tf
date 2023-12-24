resource "aws_iam_role" "SponsorApp" {
  name                 = "SponsorApp"
  description          = "SponsorApp"
  assume_role_policy   = data.aws_iam_policy_document.SponsorApp-trust.json
  max_session_duration = 43200
}

data "aws_iam_policy_document" "SponsorApp-trust" {
  statement {
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
      aws_s3_bucket.files-prd.arn,
      "${aws_s3_bucket.files-prd.arn}/*",
    ]
  }
  statement {
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
      aws_sqs_queue.activejob-prd.arn
    ]
  }

  # for app runner
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
