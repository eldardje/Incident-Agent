variable "name_prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "normalizer_arn" {
  type = string
}

variable "config_api_arn" {
  type = string
}

variable "normalizer_name" {
  type = string
}

variable "config_api_name" {
  type = string
}
