data "aws_ecs_service" "sponsor-app-worker" {
  service_name = "sponsor-app-worker"
  cluster_arn  = "arn:aws:ecs:us-west-2:005216166247:cluster/rk-usw2-fargate"
}

data "aws_ecs_task_definition" "sponsor-app-worker" {
  task_definition = data.aws_ecs_service.sponsor-app-worker.task_definition
}
