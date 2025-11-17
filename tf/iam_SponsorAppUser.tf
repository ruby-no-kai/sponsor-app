resource "aws_iam_role" "SponsorAppUser" {
  name                 = "${var.iam_role_prefix}User"
  description          = "${var.iam_role_prefix}User"
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
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
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
      "${aws_s3_bucket.files.arn}/*",
    ]
  }
}
