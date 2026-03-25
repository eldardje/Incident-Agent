output "api_id" {
  value = aws_apigatewayv2_api.http_api.id
}

output "invoke_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "execution_arn" {
  value = aws_apigatewayv2_api.http_api.execution_arn
}
