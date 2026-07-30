output "state_bucket_name" {
  description = "S3 bucket used by Terraform backends."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_region" {
  description = "Region containing the Terraform state bucket."
  value       = var.aws_region
}

output "state_kms_key_arn" {
  description = "KMS key used to encrypt Terraform state."
  value       = aws_kms_key.state.arn
}
