variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_functions" {
  type    = bool
  default = false
}

variable "package_paths" {
  type = map(string)
}

variable "table_names" {
  type = map(string)
}

variable "secret_arns" {
  type = map(string)
}

variable "incident_topic_arn" {
  type = string
}
