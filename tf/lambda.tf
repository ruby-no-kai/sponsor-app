resource "aws_lambda_function" "app" {
  for_each = var.enable_app ? {
    web = {
      handler     = "config/lambda_rack.LambdaRackApp.handle"
      memory_size = 1024
      timeout     = 90
    }
    lambdakiq = {
      handler     = "config/environment.Lambdakiq.cmd"
      memory_size = 1024
      timeout     = 90
    }
    runner = {
      handler     = "config/lambda_runner.CommandRunner.handle"
      memory_size = 2048
      timeout     = 90
    }
  } : {}

  function_name = "sponsor-app-${each.key}-${var.name}"

  package_type  = "Image"
  architectures = ["x86_64"]
  image_uri     = local.image_tag

  image_config {
    entry_point = ["/lambda_entrypoint.sh"]
  }

  role = aws_iam_role.SponsorApp.arn

  memory_size = each.value.memory_size
  timeout     = each.value.timeout

  environment {
    variables = merge(local.environments, {
      APP_HANDLER = each.value.handler # replicated to $_HANDLER at config/lambda_entrypoint.sh
    })
  }

  tags = {
    Name        = "sponsor-app-${each.key}-${var.name}"
    Component   = each.key
    Environment = var.environment
  }

  #lifecycle {
  #  ignore_changes = [
  #    image_uri,
  #  ]
  #}
}

resource "aws_lambda_event_source_mapping" "lambdakiq" {
  count = var.enable_app && var.enable_sqs ? 1 : 0

  event_source_arn = aws_sqs_queue.lambdakiq[0].arn
  function_name    = aws_lambda_function.app["lambdakiq"].arn
  batch_size       = 1

  function_response_types = ["ReportBatchItemFailures"]
}
