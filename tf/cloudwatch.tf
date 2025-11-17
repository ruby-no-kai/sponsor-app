resource "aws_cloudwatch_log_group" "worker" {
  count             = var.enable_shared_resources ? 1 : 0
  name              = "/ecs/sponsor-app-worker"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "batch" {
  count             = var.enable_shared_resources ? 1 : 0
  name              = "/ecs/sponsor-app-batch"
  retention_in_days = 3
}
