variable "name_prefix" {
  description = "Prefix for resource naming."
  type        = string
}

variable "tags" {
  description = "Tags applied to all ECS resources."
  type        = map(string)
  default     = {}
}

variable "deploy_ecs" {
  description = "Enable ECS service creation."
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "Private subnet IDs for ECS tasks."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security groups for ECS tasks."
  type        = list(string)
  default     = []
}

variable "ui_image" {
  description = "Container image for the Next.js UI service."
  type        = string
}

variable "n8n_image" {
  description = "Container image for the n8n service."
  type        = string
}

variable "secret_arns" {
  description = "Secret ARNs keyed by logical name."
  type        = map(string)
}

variable "api_gateway_invoke_url" {
  description = "HTTP API Gateway invoke URL."
  type        = string
}

variable "incident_topic_arn" {
  description = "SNS topic ARN for incident alarms."
  type        = string
}
