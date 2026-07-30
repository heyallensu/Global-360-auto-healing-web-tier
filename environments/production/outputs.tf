output "alb_url" {
  description = "Public URL of the web tier."
  value       = "http://${module.alb.dns_name}"
}

output "autoscaling_group_name" {
  description = "ASG used for self-healing verification."
  value       = module.compute.autoscaling_group_name
}

output "target_group_arn" {
  description = "Target group used for direct health verification."
  value       = module.alb.target_group_arn
}

output "sns_topic_arn" {
  description = "SNS topic receiving CloudWatch alarms."
  value       = module.alb.sns_topic_arn
}

output "nat_gateway_id" {
  description = "Single zonal NAT Gateway used by private subnets."
  value       = module.network.nat_gateway_id
}
