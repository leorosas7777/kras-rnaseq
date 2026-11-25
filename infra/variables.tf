variable "region" {
  description = "region"
  type        = string
  default     = "us-east-2"
}


variable "project" {
  description = "project"
  type        = string
  default     = "kras-rnaseq"
}

variable "work_retention_days" {
  description = "work_retention_days"
  type        = number
  default     = "7"
}
