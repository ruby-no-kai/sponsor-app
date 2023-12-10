resource "aws_s3_bucket" "files-prd" {
  provider = aws.apne1
  bucket   = "rk-sponsorship-files-prd"
}

resource "aws_s3_bucket" "files-dev" {
  provider = aws.apne1
  bucket   = "rk-sponsorship-files-dev"
}

import {
  id = "rk-sponsorship-files-prd"
  to = aws_s3_bucket.files-prd
}
import {
  id = "rk-sponsorship-files-dev"
  to = aws_s3_bucket.files-dev
}
