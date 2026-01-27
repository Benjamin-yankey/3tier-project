# Data source to get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source to get current AWS region
data "aws_region" "current" {}
