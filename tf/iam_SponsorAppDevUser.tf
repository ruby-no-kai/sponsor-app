resource "aws_iam_role" "SponsorAppDevUser" {
  name                 = "SponsorAppDevUser"
  description          = "SponsorAppDevUser"
  assume_role_policy   = data.aws_iam_policy_document.SponsorAppDevUser-trust.json
  max_session_duration = 43200
}

data "aws_iam_policy_document" "SponsorAppDevUser-trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${local.aws_account_id}:root",
      ]
    }
  }
}

resource "aws_iam_role_policy" "SponsorAppDevUser" {
  role   = aws_iam_role.SponsorAppDevUser.name
  policy = data.aws_iam_policy_document.SponsorAppDevUser.json
}
data "aws_iam_policy_document" "SponsorAppDevUser" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.files-dev.arn}/*",
    ]
  }
}
