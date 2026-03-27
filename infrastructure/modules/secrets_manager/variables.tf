variable "name_prefix" {
  description = "Prefix for secret naming."
  type        = string
}

variable "tags" {
  description = "Tags applied to all secrets."
  type        = map(string)
  default     = {}
}
