resource "aws_iam_role" "SponsorAppDev" {
  name                 = "SponsorAppDev"
  description          = "SponsorAppDev"
  assume_role_policy   = data.aws_iam_policy_document.SponsorAppDev-trust.json
  max_session_duration = 43200
}

data "aws_iam_policy_document" "SponsorAppDev-trust" {
  statement {
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
      values   = ["${data.aws_caller_identity.current.account_id}:SponsorAppDev:*"]
    }
  }

}

resource "aws_iam_role_policy" "SponsorAppDev" {
  role   = aws_iam_role.SponsorAppDev.name
  policy = data.aws_iam_policy_document.SponsorAppDev.json
}
data "aws_iam_policy_document" "SponsorAppDev" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    resources = [
      aws_iam_role.SponsorAppDevUser.arn,
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
      aws_s3_bucket.files-dev.arn,
      "${aws_s3_bucket.files-dev.arn}/*",
    ]
  }
}
