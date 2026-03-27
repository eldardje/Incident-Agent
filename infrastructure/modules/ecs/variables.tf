variable "name_prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "deploy_ecs" {
  type    = bool
  default = false
}

variable "subnet_ids" {
  type    = list(string)
  default = []
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "ui_image" {
  type = string
}

variable "n8n_image" {
  type = string
}

variable "secret_arns" {
  type = map(string)
}

variable "api_gateway_invoke_url" {
  type = string
}

variable "incident_topic_arn" {
  type = string
}
