data "aws_dynamodb_table" "rk-terraform" {
  provider = aws.apne1
  name     = "rk-terraform"
}
