variable "name_prefix" {
  description = "Prefix used for ALB resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC containing the ALB and targets."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR allowed as the ALB egress destination."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs in two Availability Zones."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) == 2
    error_message = "public_subnet_ids must contain exactly two subnets."
  }
}

variable "alarm_email" {
  description = "Optional SNS email subscriber."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.alarm_email == null ? true : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alarm_email))
    error_message = "alarm_email must be null or a valid email address."
  }
}
