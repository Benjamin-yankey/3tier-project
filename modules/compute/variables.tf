variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group ID for app servers"
  type        = string
}

variable "db_host" {
  description = "Database host"
  type        = string
}

variable "db_user" {
  description = "Database user"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}




variable "private_app_subnet_ids" {
  description = "Private app subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for bastion"
  type        = list(string)
}



variable "bastion_security_group_id" {
  description = "Security group ID for bastion host"
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN for ASG"
  type        = string
}

variable "asg_desired_capacity" {
  description = "Desired capacity for ASG"
  type        = number
}

variable "asg_min_size" {
  description = "Minimum size for ASG"
  type        = number
}

variable "asg_max_size" {
  description = "Maximum size for ASG"
  type        = number
}

variable "ssh_key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "create_bastion" {
  description = "Whether to create a bastion host"
  type        = bool
}

variable "db_credentials_secret_id" {
  description = "Secrets Manager secret ID for database credentials"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  type        = string
}
