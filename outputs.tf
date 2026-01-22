output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.alb.target_group_arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.asg_name
}

# output "rds_endpoint" {
#   description = "RDS database endpoint"
#   value       = module.database.db_endpoint
# }

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = module.compute.instance_ids
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}
