variable "environment" {
  type        = string
  description = "Environment identifier (production, dev)"
}

variable "service_name" {
  type        = string
  description = "Name for AppRunner service and tags"
}

variable "sqs_name_suffix" {
  type        = string
  description = "Suffix for SQS queue names (prd, dev)"
}

variable "iam_role_prefix" {
  type        = string
  description = "PascalCase prefix for IAM role names (e.g., SponsorAppDev, SponsorApp)"
}

variable "iam_apprunner_access_name" {
  type        = string
  description = "Name for AppRunner ECR access IAM role"
}

variable "enable_shared_resources" {
  type        = bool
  description = "Enable shared resources (ECR, CloudWatch, EcsExec, GhaDeploy) - only true for prd"
  default     = false
}

variable "s3_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for sponsor files"
}

variable "s3_cors_origins" {
  type        = list(string)
  description = "List of allowed CORS origins for S3 bucket"
}

variable "enable_cloudfront" {
  type        = bool
  default     = false
  description = "Enable CloudFront distribution"
}

variable "enable_sqs" {
  type        = bool
  default     = false
  description = "Enable SQS queues for ActiveJob"
}

variable "enable_apprunner" {
  type        = bool
  default     = false
  description = "Enable App Runner service"
}

variable "enable_amc_oidc" {
  type        = bool
  default     = false
  description = "Enable AMC OIDC trust for app role (dev only)"
}

variable "app_domain" {
  type        = string
  default     = null
  description = "Application domain for CloudFront (required if enable_cloudfront is true)"
}

variable "certificate_arn" {
  type        = string
  default     = null
  description = "ACM certificate ARN for CloudFront (required if enable_cloudfront is true)"
}

variable "cloudfront_log_bucket" {
  type        = string
  default     = ""
  description = "S3 bucket for CloudFront logs"
}

variable "cloudfront_log_prefix" {
  type        = string
  default     = ""
  description = "Prefix for CloudFront logs in S3"
}

variable "cloudfront_comment" {
  type        = string
  default     = ""
  description = "Comment for CloudFront distribution"
}

variable "github_actions_sub" {
  type        = string
  description = "GitHub Actions OIDC subject for deployment role"
}

variable "environments" {
  type        = map(string)
  default     = {}
  description = "Additional/override runtime environment variables for AppRunner"
}

variable "secrets" {
  type        = map(string)
  default     = {}
  description = "Runtime environment secrets (SSM parameter ARNs) for AppRunner"
}
