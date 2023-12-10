resource "aws_sqs_queue" "activejob-prd" {
  name = "sponsor-app-activejob-prd"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.activejob-dlq-prd.arn
    maxReceiveCount     = 10
  })

  tags = {
    Environment = "production"
  }
}

resource "aws_sqs_queue" "activejob-dlq-prd" {
  name = "sponsor-app-activejob-dlq-prd"

  tags = {
    Environment = "production"
  }
}

