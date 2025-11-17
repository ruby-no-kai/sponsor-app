resource "aws_sqs_queue" "activejob-dlq" {
  count = var.enable_sqs ? 1 : 0

  name = "sponsor-app-activejob-dlq-${var.sqs_name_suffix}"

  tags = {
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "activejob" {
  count = var.enable_sqs ? 1 : 0

  name = "sponsor-app-activejob-${var.sqs_name_suffix}"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.activejob-dlq[0].arn
    maxReceiveCount     = 10
  })

  tags = {
    Environment = var.environment
  }
}
