output "security_group_id" {
  description = "Security group attached to the ALB."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "Target group ARN attached to the ASG."
  value       = aws_lb_target_group.web.arn
}

output "dns_name" {
  description = "Public ALB DNS name."
  value       = aws_lb.this.dns_name
}

output "sns_topic_arn" {
  description = "SNS topic used by CloudWatch alarms."
  value       = aws_sns_topic.alarms.arn
}

output "sns_kms_key_arn" {
  description = "KMS key encrypting alarm notifications."
  value       = aws_kms_key.sns.arn
}
