output "table_names" {
  description = "All DynamoDB table names."
  value       = module.dynamodb.table_names
}

output "api_invoke_url" {
  description = "HTTP API invoke URL."
  value       = module.api_gateway.invoke_url
}

output "incident_topic_arn" {
  description = "SNS topic ARN for incoming CloudWatch alarms."
  value       = module.sns.topic_arn
}

output "secret_arns" {
  description = "Secrets used by incident agent services."
  value       = module.secrets_manager.secret_arns
}

output "oidc_reuse_summary" {
  description = "References to shared Career Platform resources that must be reused."
  value = {
    existing_oidc_provider_arn = var.existing_oidc_provider_arn
    existing_deploy_role_arn   = var.existing_deploy_role_arn
  }
}

output "n8n_alb_dns" {
  description = "DNS name of the n8n ALB."
  value       = module.ecs.n8n_alb_dns
}

output "n8n_webhook_url" {
  description = "n8n webhook URL subscribed to the SNS topic."
  value       = module.ecs.n8n_webhook_url
}

output "n8n_rds_endpoint" {
  description = "RDS endpoint for n8n PostgreSQL database."
  value       = module.ecs.n8n_rds_endpoint
}
