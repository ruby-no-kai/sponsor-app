resource "aws_iam_role" "SponsorAppUser" {
  name                 = "SponsorAppUser"
  description          = "SponsorAppUser"
  assume_role_policy   = data.aws_iam_policy_document.SponsorAppUser-trust.json
  max_session_duration = 43200
}

data "aws_iam_policy_document" "SponsorAppUser-trust" {
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

resource "aws_iam_role_policy" "SponsorAppUser" {
  role   = aws_iam_role.SponsorAppUser.name
  policy = data.aws_iam_policy_document.SponsorAppUser.json
}
data "aws_iam_policy_document" "SponsorAppUser" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.files-prd.arn}/*",
    ]
  }
}
