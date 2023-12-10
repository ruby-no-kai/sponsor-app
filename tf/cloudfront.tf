resource "aws_cloudfront_distribution" "prd" {
  comment = "sponsor-app"

  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = "PriceClass_All"

  aliases = ["sponsorships.rubykaigi.org"]

  viewer_certificate {
    acm_certificate_arn            = data.aws_acm_certificate.use1-sponsorships-rk-o.arn
    cloudfront_default_certificate = false
    iam_certificate_id             = null
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  logging_config {
    bucket          = "rk-aws-logs.s3.amazonaws.com"
    include_cookies = false
    prefix          = "cf/sponsorships.rubykaigi.org/"
  }

  origin {
    origin_id           = "apprunner"
    domain_name         = replace(aws_apprunner_service.prd.service_url, "https://", "")
    origin_path         = null
    connection_attempts = 3
    connection_timeout  = 10
    custom_header {
      name  = "x-forwarded-host"
      value = "sponsorships.rubykaigi.org"
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
    target_origin_id = "apprunner"
    path_pattern     = "/packs/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]

    compress = true

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      headers                 = []
      query_string            = false
      query_string_cache_keys = []
      cookies {
        forward           = "none"
        whitelisted_names = []
      }
    }
  }

  default_cache_behavior {
    target_origin_id = "apprunner"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]

    compress = true

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 31536000

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      headers                 = ["x-csrf-token", "User-Agent", "Origin"]
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
import {
  to = aws_cloudfront_distribution.prd
  id = "E2ZBMTEBD45786"
}
