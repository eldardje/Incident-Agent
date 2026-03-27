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

# --- Networking ---

variable "vpc_id" {
  description = "VPC ID for ALB target group and security groups."
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Private subnet IDs for ECS tasks, EFS mount targets, and RDS."
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security groups for ECS tasks."
  type        = list(string)
  default     = []
}

variable "efs_security_group_ids" {
  description = "Security groups for EFS mount targets."
  type        = list(string)
  default     = []
}

variable "alb_security_group_ids" {
  description = "Security groups for the n8n ALB."
  type        = list(string)
  default     = []
}

variable "rds_security_group_ids" {
  description = "Security groups for the RDS instance."
  type        = list(string)
  default     = []
}

# --- Container images ---

variable "ui_image" {
  description = "Container image for the Next.js UI service."
  type        = string
}

variable "n8n_image" {
  description = "Container image for the n8n service."
  type        = string
}

# --- Secrets & Integration ---

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

variable "analyzer_invoke_url" {
  description = "Invoke URL for the Analyzer Lambda function."
  type        = string
  default     = ""
}

# --- n8n configuration ---

variable "n8n_domain" {
  description = "Domain name for the n8n instance (e.g., n8n.incident-agent.example.com)."
  type        = string
  default     = ""
}

variable "n8n_certificate_arn" {
  description = "ACM certificate ARN for the n8n ALB HTTPS listener."
  type        = string
  default     = ""
}

variable "n8n_db_password" {
  description = "Password for the n8n PostgreSQL database."
  type        = string
  sensitive   = true
  default     = ""
}
