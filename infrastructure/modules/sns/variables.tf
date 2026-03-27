variable "name_prefix" {
  description = "Prefix for resource naming."
  type        = string
}

variable "tags" {
  description = "Tags applied to all SNS resources."
  type        = map(string)
  default     = {}
}
