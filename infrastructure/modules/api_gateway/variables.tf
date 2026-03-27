variable "name_prefix" {
  description = "Prefix for resource naming."
  type        = string
}

variable "tags" {
  description = "Tags applied to all API Gateway resources."
  type        = map(string)
  default     = {}
}

variable "create_integrations" {
  description = "Create Lambda integrations, routes, and permissions. Set to true only when Lambda functions are deployed."
  type        = bool
  default     = false
}

variable "normalizer_arn" {
  description = "Invoke ARN for the normalizer Lambda function."
  type        = string
}

variable "config_api_arn" {
  description = "Invoke ARN for the config API Lambda function."
  type        = string
}

variable "normalizer_name" {
  description = "Function name for the normalizer Lambda."
  type        = string
}

variable "config_api_name" {
  description = "Function name for the config API Lambda."
  type        = string
}
