locals {
  image_tag = var.enable_app ? "${aws_ecr_repository.app[0].repository_url}:df33dc1a82f134e839419bea35d966516d4deee3" : null

  default_environments = {
    # Rails defaults
    LANG                     = "C.UTF-8"
    RACK_ENV                 = var.environment
    RAILS_ENV                = var.environment
    RAILS_LOG_TO_STDOUT      = "1"
    RAILS_SERVE_STATIC_FILES = "1"
    WEB_CONCURRENCY          = "0"
    RAILS_MAX_THREADS        = "2"

    # Organization defaults
    ORG_NAME = "RubyKaigi"

    # Computed from module resources
    S3_FILES_REGION = "ap-northeast-1"
    S3_FILES_BUCKET = aws_s3_bucket.files.id
    S3_FILES_ROLE   = aws_iam_role.SponsorAppUser.arn

    # Conditional: SQS (only when enabled)
    JOB_ADAPTER     = var.enable_sqs ? "lambdakiq" : "inline"
    LAMBDAKIQ_QUEUE = var.enable_sqs ? aws_sqs_queue.lambdakiq[0].name : ""

    CLOUDFRONT_VERIFY = random_bytes.cloudfront_verify.base64
  }

  # Empty for now, will be populated when SSM parameters are migrated to Terraform
  default_secrets = {}

  # Transform secrets to SSM_SECRET__ environment variables for dynamic loading
  secret_loader_environments = {
    for key, arn in var.secrets :
    "SSM_SECRET__${key}" => arn
  }

  # Final merged values
  environments = merge(local.default_environments, local.secret_loader_environments, var.environments)
  secrets      = merge(local.default_secrets, var.secrets)
}
