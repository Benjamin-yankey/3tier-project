# ============================================================================
# COMPUTE MODULE - OUTPUTS
# ============================================================================
# This file exposes important resource attributes to the root module
# These outputs can be used by other modules or displayed to users

# ============================================================================
# AUTO SCALING GROUP OUTPUTS
# ============================================================================

# Name of the Auto Scaling Group
# Useful for AWS CLI commands, monitoring, and debugging
# Example: "3tier-app-dev-asg"
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

# ============================================================================
# BASTION HOST OUTPUTS
# ============================================================================

# IDs of bastion host instances (if created)
# Returns empty list if create_bastion = false
# Use this to SSH into bastion: ssh -i key.pem ubuntu@<public-ip>
output "instance_ids" {
  description = "IDs of EC2 instances"
  value       = aws_instance.bastion[*].id
}

# Private IP addresses of bastion hosts
# Used for internal communication and security group rules
output "instance_private_ips" {
  description = "Private IPs of EC2 instances"
  value       = aws_instance.bastion[*].private_ip
}
