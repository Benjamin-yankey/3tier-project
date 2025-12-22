# Data source to get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}
