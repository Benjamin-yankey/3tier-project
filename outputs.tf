output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
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
