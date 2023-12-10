resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/sponsor-app-worker"
  retention_in_days = 3
}
resource "aws_cloudwatch_log_group" "batch" {
  name              = "/ecs/sponsor-app-batch"
  retention_in_days = 3
}
