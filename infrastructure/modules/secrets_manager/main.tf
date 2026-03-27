resource "aws_secretsmanager_secret" "slack_webhook" {
  name = "${var.name_prefix}/slack/webhook"
  tags = var.tags
}

resource "aws_secretsmanager_secret" "ses_credentials" {
  name = "${var.name_prefix}/ses/credentials"
  tags = var.tags
}

resource "aws_secretsmanager_secret" "n8n_db_password" {
  name = "${var.name_prefix}/n8n/db-password"
  tags = var.tags
}

resource "aws_secretsmanager_secret" "n8n_encryption_key" {
  name = "${var.name_prefix}/n8n/encryption-key"
  tags = var.tags
}
