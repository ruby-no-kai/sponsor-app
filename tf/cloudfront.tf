data "aws_cloudfront_origin_request_policy" "Managed-AllViewerExceptHostHeader" {
  name = "Managed-AllViewerExceptHostHeader"
}
data "aws_cloudfront_cache_policy" "Managed-CachingDisabled" {
  name = "Managed-CachingDisabled"
}
data "aws_cloudfront_cache_policy" "Managed-CachingOptimized" {
  name = "Managed-CachingOptimized"
}


resource "aws_cloudfront_distribution" "main" {
  count = var.enable_cloudfront ? 1 : 0

  provider = aws.cloudfront

  comment = var.cloudfront_comment != "" ? var.cloudfront_comment : "sponsor-app"

  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = "PriceClass_All"

  aliases = [var.app_domain]

  viewer_certificate {
    acm_certificate_arn            = var.certificate_arn
    cloudfront_default_certificate = false
    iam_certificate_id             = null
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  dynamic "logging_config" {
    for_each = var.cloudfront_log_bucket != "" ? [1] : []
    content {
      bucket          = var.cloudfront_log_bucket
      include_cookies = false
      prefix          = var.cloudfront_log_prefix
    }
  }

  origin {
    origin_id           = "functionurl"
    domain_name         = replace(replace(aws_lambda_function_url.app[0].function_url, "https://", ""), "/", "")
    origin_path         = null
    connection_attempts = 3
    connection_timeout  = 10
    custom_header {
      name  = "x-forwarded-host"
      value = var.app_domain
    }
    custom_header {
      name  = "x-origin-verify"
      value = random_bytes.cloudfront_verify.base64
    }
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  origin {
    origin_id           = "apprunner"
    domain_name         = replace(aws_apprunner_service.main[0].service_url, "https://", "")
    origin_path         = null
    connection_attempts = 3
    connection_timeout  = 10
    custom_header {
      name  = "x-forwarded-host"
      value = var.app_domain
    }
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  ordered_cache_behavior {
    target_origin_id = "functionurl"
    path_pattern     = "/vite/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]

    #origin_request_policy_id = data.aws_cloudfront_origin_request_policy.Managed-AllViewerExceptHostHeader.id

    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.Managed-CachingOptimized.id
    viewer_protocol_policy = "redirect-to-https"
  }

  default_cache_behavior {
    target_origin_id = "functionurl"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]

    compress = true

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 31536000

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      headers                 = ["x-csrf-token", "User-Agent", "Origin", "CloudFront-Viewer-Country"]
      query_string            = true
      query_string_cache_keys = []
      cookies {
        forward           = "whitelist"
        whitelisted_names = ["__Host-rk-sponsorapp2-sess", "sponsorapp2"]
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "random_bytes" "cloudfront_verify" {
  length = 32
}
