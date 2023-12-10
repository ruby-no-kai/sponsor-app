data "aws_acm_certificate" "wild-rk-n" {
  domain      = "*.rubykaigi.net"
  most_recent = true
}

data "aws_acm_certificate" "use1-sponsorships-rk-o" {
  provider    = aws.use1
  domain      = "sponsorships.rubykaigi.org"
  most_recent = true
}
