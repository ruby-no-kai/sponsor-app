terraform {
  backend "s3" {
    bucket               = "rk-infra"
    workspace_key_prefix = "terraform"
    key                  = "terraform/sponsor-app.tfstate"
    region               = "ap-northeast-1"
    dynamodb_table       = "rk-terraform"
  }
}

data "aws_dynamodb_table" "rk-terraform" {
  provider = aws.apne1
  name     = "rk-terraform"
}
