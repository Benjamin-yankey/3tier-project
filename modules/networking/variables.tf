variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}