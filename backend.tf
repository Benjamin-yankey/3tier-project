# terraform {
#   backend "s3" {
#     bucket         = "3tier-terraform-state"
#     key            = "terraform.tfstate"
#     region         = "eu-west-1"
#     encrypt        = true
#     use_lockfile   = true
#     
#     # Update bucket name after running setup-backend.sh
#     # Variables are not allowed in backend configuration
#   }
# }
