resource "aws_secretsmanager_secret" "slack_webhook" {
  name = "${var.name_prefix}/slack/webhook"
  tags = var.tags
}

resource "aws_secretsmanager_secret" "ses_credentials" {
  name = "${var.name_prefix}/ses/credentials"
  tags = var.tags
}
