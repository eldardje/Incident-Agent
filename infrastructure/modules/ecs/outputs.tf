output "cluster_arn" {
  description = "ECS cluster ARN, null when ECS is not deployed."
  value       = var.deploy_ecs ? aws_ecs_cluster.this[0].arn : null
}

output "service_names" {
  description = "ECS service names keyed by service id, null when ECS is not deployed."
  value = var.deploy_ecs ? {
    n8n = aws_ecs_service.n8n[0].name
    ui  = aws_ecs_service.ui[0].name
    } : {
    n8n = null
    ui  = null
  }
}

output "n8n_alb_dns" {
  description = "DNS name of the n8n ALB."
  value       = var.deploy_ecs ? aws_lb.n8n[0].dns_name : null
}

output "n8n_webhook_url" {
  description = "n8n webhook URL for CloudWatch alarm SNS subscription."
  value       = var.deploy_ecs && var.n8n_domain != "" ? "https://${var.n8n_domain}/webhook/cloudwatch-alarm" : null
}

output "n8n_rds_endpoint" {
  description = "RDS endpoint for n8n PostgreSQL database."
  value       = var.deploy_ecs ? aws_db_instance.n8n[0].endpoint : null
}

output "n8n_efs_id" {
  description = "EFS file system ID for n8n persistent storage."
  value       = var.deploy_ecs ? aws_efs_file_system.n8n[0].id : null
}
