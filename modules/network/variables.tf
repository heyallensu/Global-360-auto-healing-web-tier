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
