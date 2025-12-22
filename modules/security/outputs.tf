output "alb_sg_id" {
  description = "ALB Security Group ID"
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "App Security Group ID"
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "DB Security Group ID"
  value       = aws_security_group.db.id
}
output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}
