resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.name_prefix}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers  = ["*"]
    allow_methods  = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_origins  = ["*"]
    expose_headers = ["*"]
    max_age        = 86400
  }

  tags = var.tags
}

resource "aws_apigatewayv2_integration" "webhook" {
  count = var.create_integrations ? 1 : 0

  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.normalizer_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "config_api" {
  count = var.create_integrations ? 1 : 0

  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.config_api_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webhook" {
  count = var.create_integrations ? 1 : 0

  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.webhook[0].id}"
}

resource "aws_apigatewayv2_route" "config_api_proxy" {
  count = var.create_integrations ? 1 : 0

  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.config_api[0].id}"
}

resource "aws_apigatewayv2_route" "config_api_root" {
  count = var.create_integrations ? 1 : 0

  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /api"
  target    = "integrations/${aws_apigatewayv2_integration.config_api[0].id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  tags = var.tags
}

resource "aws_lambda_permission" "allow_http_api_webhook" {
  count = var.create_integrations ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGatewayWebhook"
  action        = "lambda:InvokeFunction"
  function_name = var.normalizer_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*/webhook"
}

resource "aws_lambda_permission" "allow_http_api_config" {
  count = var.create_integrations ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGatewayConfig"
  action        = "lambda:InvokeFunction"
  function_name = var.config_api_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*/api*"
}
