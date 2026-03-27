variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
  default     = "incident-agent"
}

variable "aws_region" {
  description = "AWS region for resources."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Additional tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "existing_oidc_provider_arn" {
  description = "Existing shared GitHub OIDC provider ARN from Career Platform."
  type        = string
  default     = ""
}

variable "existing_deploy_role_arn" {
  description = "Existing shared deploy role ARN trusted by OIDC from Career Platform."
  type        = string
  default     = ""
}

variable "enable_deletion_protection" {
  description = "Enable DynamoDB deletion protection. Disable for dev environments."
  type        = bool
  default     = true
}

variable "deploy_ecs" {
  description = "Enable ECS service creation."
  type        = bool
  default     = false
}

variable "create_lambda_functions" {
  description = "Enable Lambda function creation when package artifacts are available."
  type        = bool
  default     = false
}

variable "lambda_package_paths" {
  description = "Zip artifact paths for lambda functions keyed by normalizer, analyzer, config_api."
  type        = map(string)
  default = {
    normalizer = ""
    analyzer   = ""
    config_api = ""
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks."
  type        = list(string)
  default     = []
}

variable "ecs_security_group_ids" {
  description = "Security groups for ECS tasks."
  type        = list(string)
  default     = []
}

variable "ui_image" {
  description = "Container image for Next.js UI."
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:stable"
}

variable "n8n_image" {
  description = "Container image for n8n service."
  type        = string
  default     = "docker.n8n.io/n8nio/n8n:latest"
}
