output "secret_arns" {
  value = {
    slack_webhook   = aws_secretsmanager_secret.slack_webhook.arn
    ses_credentials = aws_secretsmanager_secret.ses_credentials.arn
  }
}
