variable "name_prefix" {
  description = "Prefix used for compute resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC containing the instances."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets used by the ASG."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) == 2
    error_message = "private_subnet_ids must contain exactly two subnets."
  }
}

variable "alb_security_group_id" {
  description = "ALB security group allowed to reach instance port 80."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group attached to the ASG."
  type        = string
}

variable "instance_type" {
  description = "ARM64 EC2 instance type."
  type        = string
}

variable "container_image" {
  description = "Immutable public GHCR manifest digest."
  type        = string

  validation {
    condition     = can(regex("^ghcr\\.io/.+@sha256:[0-9a-f]{64}$", var.container_image))
    error_message = "container_image must be a GHCR sha256 manifest digest."
  }
}

variable "min_size" {
  description = "Minimum ASG size."
  type        = number
}

variable "desired_capacity" {
  description = "Desired ASG capacity."
  type        = number
}

variable "max_size" {
  description = "Maximum ASG size."
  type        = number
}
