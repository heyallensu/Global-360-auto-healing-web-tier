variable "name_prefix" {
  description = "Prefix used for network resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC."
  type        = string
}

variable "aws_region" {
  description = "AWS Region used to form endpoint service names."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count == 2
    error_message = "This assessment requires exactly two Availability Zones."
  }
}
