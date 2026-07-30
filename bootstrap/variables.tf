variable "project_name" {
  description = "Short project identifier used in resource names."
  type        = string
  default     = "global-360"
}

variable "aws_region" {
  description = "AWS Region for remote state resources."
  type        = string
  default     = "ap-southeast-2"
}
