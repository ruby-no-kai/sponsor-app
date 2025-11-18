output "ecr_repository_url" {
  value       = var.enable_shared_resources ? aws_ecr_repository.app[0].repository_url : null
  description = "ECR repository URL"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.files.id
  description = "S3 bucket name for sponsor files"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.files.arn
  description = "S3 bucket ARN"
}

output "app_role_arn" {
  value       = aws_iam_role.SponsorApp.arn
  description = "IAM role ARN for sponsor app"
}

output "app_user_role_arn" {
  value       = aws_iam_role.SponsorAppUser.arn
  description = "IAM role ARN for sponsor app user (S3 uploads)"
}

output "cloudfront_distribution_id" {
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].id : null
  description = "CloudFront distribution ID"
}

output "cloudfront_distribution_domain_name" {
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].domain_name : null
  description = "CloudFront distribution domain name"
}

output "sqs_queue_url" {
  value       = var.enable_sqs ? aws_sqs_queue.activejob[0].url : null
  description = "SQS queue URL for ActiveJob"
}

output "apprunner_service_url" {
  value       = var.enable_app ? aws_apprunner_service.main[0].service_url : null
  description = "App Runner service URL"
}
