output "cluster_arn" {
  value = var.deploy_ecs ? aws_ecs_cluster.this[0].arn : null
}

output "service_names" {
  value = var.deploy_ecs ? {
    n8n = aws_ecs_service.n8n[0].name
    ui  = aws_ecs_service.ui[0].name
    } : {
    n8n = null
    ui  = null
  }
}
