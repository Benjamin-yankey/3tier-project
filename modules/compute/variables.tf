# ============================================================================
# COMPUTE MODULE - INPUT VARIABLES
# ============================================================================
# This file defines all input variables for the compute module
# Variables are organized by category for easy navigation

# ============================================================================
# COMMON VARIABLES
# ============================================================================

# Tags applied to all resources for organization, cost tracking, and management
# Example: { project_name = "3tier-app", environment = "dev", owner = "team" }
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

# ============================================================================
# NETWORKING VARIABLES
# ============================================================================

# Private subnets where EC2 instances will be deployed (isolated from internet)
variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

# Private app-tier subnets for Auto Scaling Group (spans multiple AZs for HA)
variable "private_app_subnet_ids" {
  description = "Private app subnet IDs"
  type        = list(string)
}

# Public subnets for bastion host (has internet access for SSH)
variable "public_subnet_ids" {
  description = "Public subnet IDs for bastion"
  type        = list(string)
}

# ============================================================================
# SECURITY VARIABLES
# ============================================================================

# Security group controlling traffic to/from application servers
# Allows traffic from ALB and SSH from bastion
variable "app_security_group_id" {
  description = "Security group ID for app servers"
  type        = string
}

# Security group for bastion host (allows SSH from specific IPs only)
variable "bastion_security_group_id" {
  description = "Security group ID for bastion host"
  type        = string
}

# SSH key pair name for EC2 instance authentication
# Must be created in AWS before deployment
variable "ssh_key_name" {
  description = "SSH key pair name"
  type        = string
}

# ============================================================================
# DATABASE VARIABLES
# ============================================================================

# RDS endpoint (hostname:port) for database connection
# Example: "mydb.abc123.us-east-1.rds.amazonaws.com:3306"
variable "db_host" {
  description = "Database host"
  type        = string
}

# Database master username (deprecated - use Secrets Manager instead)
variable "db_user" {
  description = "Database user"
  type        = string
}

# Database master password (deprecated - use Secrets Manager instead)
variable "db_password" {
  description = "Database password"
  type        = string
}

# Name of the database to connect to (e.g., "appdb", "todoapp")
variable "db_name" {
  description = "Database name"
  type        = string
}

# Database port (3306 for MySQL, 5432 for PostgreSQL)
variable "db_port" {
  description = "Database port"
  type        = number
}

# AWS Secrets Manager secret ID containing database credentials
# Securely stores username and password as JSON: {"username":"...","password":"..."}
variable "db_credentials_secret_id" {
  description = "Secrets Manager secret ID for database credentials"
  type        = string
}

# ============================================================================
# COMPUTE VARIABLES
# ============================================================================

# EC2 instance type (size) for application servers
# t3.micro = 2 vCPU, 1 GB RAM (good for dev/test)
# t3.small = 2 vCPU, 2 GB RAM (good for small production)
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# IAM instance profile name attached to EC2 instances
# Grants permissions to access AWS services (Secrets Manager, CloudWatch, etc.)
variable "instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  type        = string
}

# ============================================================================
# AUTO SCALING GROUP VARIABLES
# ============================================================================

# ALB target group ARN where ASG instances will be registered
# ALB distributes traffic to instances in this target group
variable "target_group_arn" {
  description = "Target group ARN for ASG"
  type        = string
}

# ALB target group ARN suffix for CloudWatch metrics
# Format: targetgroup/name/suffix (extracted from full ARN)
# Used for request count per target metric in scaling policies
variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch metrics (e.g., 'targetgroup/my-target-group/1d8c9c5d27d6a8cd')"
  type        = string
  default     = "" # If empty, request-based scaling will be skipped
}

# Target number of instances ASG should maintain
# ASG will launch/terminate instances to match this number
variable "asg_desired_capacity" {
  description = "Desired capacity for ASG"
  type        = number
}

# Minimum number of instances (ASG won't scale below this)
# Ensures at least this many instances are always running
variable "asg_min_size" {
  description = "Minimum size for ASG"
  type        = number
}

# Maximum number of instances (ASG won't scale above this)
# Prevents runaway scaling and controls costs
variable "asg_max_size" {
  description = "Maximum size for ASG"
  type        = number
}

# ============================================================================
# BASTION HOST VARIABLES
# ============================================================================

# Flag to conditionally create bastion host
# Set to true for SSH access to private instances, false to save costs
variable "create_bastion" {
  description = "Whether to create a bastion host"
  type        = bool
}
