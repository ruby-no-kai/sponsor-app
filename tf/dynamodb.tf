data "aws_dynamodb_table" "rk-terraform" {
  provider = aws.files
  name     = "rk-terraform"
}
