data "aws_kms_key" "usw2_ssm" {
  key_id = "alias/aws/ssm"
}

