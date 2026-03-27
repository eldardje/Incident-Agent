variable "name_prefix" {
  description = "Prefix for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "tags" {
  description = "Tags applied to all Lambda resources."
  type        = map(string)
  default     = {}
}

variable "create_functions" {
  description = "Enable Lambda function creation when package artifacts are available."
  type        = bool
  default     = false
}

variable "package_paths" {
  description = "Zip artifact paths keyed by function name."
  type        = map(string)
}

variable "table_names" {
  description = "DynamoDB table names keyed by logical table id."
  type        = map(string)
}

variable "secret_arns" {
  description = "Secret ARNs keyed by logical name."
  type        = map(string)
}

variable "incident_topic_arn" {
  description = "SNS topic ARN for incident alarms."
  type        = string
}
