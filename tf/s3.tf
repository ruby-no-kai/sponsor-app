resource "aws_s3_bucket" "files" {
  provider = aws.files
  bucket   = var.s3_bucket_name
}

resource "aws_s3_bucket_public_access_block" "files" {
  provider = aws.files

  bucket                  = aws_s3_bucket.files.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "files" {
  provider = aws.files

  bucket = aws_s3_bucket.files.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "files" {
  provider = aws.files

  bucket = aws_s3_bucket.files.bucket

  transition_default_minimum_object_size = "varies_by_storage_class"

  rule {
    id     = "abort-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_accelerate_configuration" "files" {
  provider = aws.files

  bucket = aws_s3_bucket.files.bucket
  status = "Enabled"
}

resource "aws_s3_bucket_cors_configuration" "files" {
  provider = aws.files
  bucket   = aws_s3_bucket.files.bucket

  dynamic "cors_rule" {
    for_each = var.s3_cors_origins
    content {
      allowed_headers = ["*"]
      allowed_methods = ["DELETE", "GET", "HEAD", "POST", "PUT"]
      allowed_origins = [cors_rule.value]
      expose_headers  = ["ETag", "x-amz-version-id"]
      max_age_seconds = 0
    }
  }
}
