output "api_id" {
  description = "HTTP API Gateway ID."
  value       = aws_apigatewayv2_api.http_api.id
}

output "invoke_url" {
  description = "HTTP API Gateway invoke URL."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "execution_arn" {
  description = "HTTP API Gateway execution ARN."
  value       = aws_apigatewayv2_api.http_api.execution_arn
}
