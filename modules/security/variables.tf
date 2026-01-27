variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "owner_name" {
  description = "Owner name for tagging"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR block for admin access to bastion (restrict SSH to your IP in production)"
  type        = string
  default     = "0.0.0.0/0" # TODO: Replace with your IP/organization IP range for production
}
