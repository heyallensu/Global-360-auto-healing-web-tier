output "autoscaling_group_name" {
  description = "Name of the web ASG."
  value       = aws_autoscaling_group.web.name
}

output "instance_security_group_id" {
  description = "Security group attached to web instances."
  value       = aws_security_group.instance.id
}

output "instance_role_name" {
  description = "IAM role used by web instances."
  value       = aws_iam_role.instance.name
}
