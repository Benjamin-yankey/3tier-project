variable "aws_region" {
  description = "AWS region"
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

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string

}

variable "db_username" {
  description = "Database master username"
  type        = string

}

variable "owner_name" {
  description = "Your name for tagging"
  type        = string

}

variable "ssh_key_name" {
  description = "SSH key pair name for EC2 instances"
  type        = string

}

variable "db_user" {
  description = "Database user"
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


