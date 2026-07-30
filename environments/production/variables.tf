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
}

variable "instance_type" {
  description = "ARM64 EC2 instance type used by the ASG."
  type        = string
  default     = "t4g.micro"
}

variable "container_image" {
  description = "Immutable public GHCR manifest digest."
  type        = string
}

variable "asg_min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Normal number of instances."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 4
}
