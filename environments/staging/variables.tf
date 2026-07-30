variable "project_name" {
  description = "Short project identifier used in names and tags."
  type        = string
  default     = "global-360"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "aws_region" {
  description = "AWS Region for the workload."
  type        = string
  default     = "ap-southeast-2"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "alarm_email" {
  description = "Optional email address for SNS alarm notifications."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.alarm_email == null ? true : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alarm_email))
    error_message = "alarm_email must be null or a valid email address."
  }
}
