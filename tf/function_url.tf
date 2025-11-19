resource "aws_lambda_function_url" "app" {
  count              = var.enable_app ? 1 : 0
  function_name      = aws_lambda_function.app["web"].function_name
  authorization_type = "NONE"
}

output "function_url" {
  value = var.enable_app ? aws_lambda_function_url.app[0].function_url : null
}
