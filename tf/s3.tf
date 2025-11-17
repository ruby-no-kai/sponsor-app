resource "aws_s3_bucket" "files-prd" {
  provider = aws.apne1
  bucket   = "rk-sponsorship-files-prd"
}

resource "aws_s3_bucket" "files-dev" {
  provider = aws.apne1
  bucket   = "rk-sponsorship-files-dev"
}

locals {
  buckets = {
    prd = aws_s3_bucket.files-prd.bucket,
    dev = aws_s3_bucket.files-dev.bucket
  }
}

resource "aws_s3_bucket_public_access_block" "files" {
  for_each = local.buckets
  provider = aws.apne1

  bucket                  = each.value
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "files" {
  for_each = local.buckets
  provider = aws.apne1

  bucket = each.value

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "files" {
  for_each = local.buckets
  provider = aws.apne1

  bucket = each.value

  transition_default_minimum_object_size = "varies_by_storage_class"

  rule {
    id     = "abort-multipart"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_accelerate_configuration" "files" {
  for_each = local.buckets
  provider = aws.apne1

  bucket = each.value
  status = "Enabled"
}


resource "aws_s3_bucket_cors_configuration" "files-dev" {
  provider = aws.apne1
  bucket   = aws_s3_bucket.files-dev.bucket
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["DELETE", "GET", "HEAD", "POST", "PUT"]
    allowed_origins = ["http://localhost:13000"]
    expose_headers  = ["ETag", "x-amz-version-id"]
    max_age_seconds = 0
  }
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["DELETE", "GET", "HEAD", "POST", "PUT"]
    allowed_origins = ["http://localhost:13010"]
    expose_headers  = ["ETag", "x-amz-version-id"]
    max_age_seconds = 0
  }
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["DELETE", "GET", "HEAD", "POST", "PUT"]
    allowed_origins = ["http://localhost:3000"]
    expose_headers  = ["ETag", "x-amz-version-id"]
    max_age_seconds = 0
  }
}

resource "aws_s3_bucket_cors_configuration" "files-prd" {
  provider = aws.apne1
  bucket   = aws_s3_bucket.files-prd.bucket
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["DELETE", "GET", "HEAD", "POST", "PUT"]
    allowed_origins = ["https://sponsorships.rubykaigi.org"]
    expose_headers  = ["ETag", "x-amz-version-id"]
    max_age_seconds = 0
  }
}


