variable "name_prefix" {
  description = "Prefix for table naming."
  type        = string
}

variable "tags" {
  description = "Tags applied to all tables."
  type        = map(string)
  default     = {}
}

variable "enable_deletion_protection" {
  description = "Prevent accidental table deletion. Disable for dev environments."
  type        = bool
  default     = true
}
