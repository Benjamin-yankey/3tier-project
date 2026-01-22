locals {
  common_tags = {
    project_name = var.project_name
    environment  = var.environment
    owner_name   = var.owner_name
  }
}

# ============================================
# TIER 0: Foundation (Networking & Security)
# ============================================

# Networking - VPC, Subnets, IGW, NAT Gateway
module "networking" {
  source = "./modules/networking"

  vpc_cidr    = var.vpc_cidr
  common_tags = local.common_tags
}

# Security Groups
module "security" {
  source = "./modules/security"

  vpc_id       = module.networking.vpc_id
  project_name = var.project_name
  environment  = var.environment
  owner_name   = var.owner_name

  depends_on = [module.networking]
}

# ============================================
# TIER 3: Data Layer (Database)
# ============================================

module "database" {
  source = "./modules/database"

  common_tags           = local.common_tags
  private_db_subnet_ids = module.networking.private_db_subnet_ids
  db_security_group_id  = module.security.db_sg_id
  db_username           = var.db_username
  db_password           = random_password.db_password.result
  db_instance_class     = "db.t3.micro"
  allocated_storage     = 20

  depends_on = [module.networking, module.security]
}

# ============================================
# TIER 1: Presentation Layer (Load Balancer)
# ============================================

module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  owner_name            = var.owner_name
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security.alb_sg_id

  depends_on = [module.networking, module.security]
}

# ============================================
# TIER 2: Application Layer (Compute)
# ============================================

module "compute" {
  source = "./modules/compute"

  common_tags               = local.common_tags
  private_subnet_ids        = module.networking.private_app_subnet_ids
  private_app_subnet_ids    = module.networking.private_app_subnet_ids
  public_subnet_ids         = module.networking.public_subnet_ids
  app_security_group_id     = module.security.app_sg_id
  bastion_security_group_id = module.security.bastion_sg_id
  target_group_arn          = module.alb.target_group_arn

  instance_type        = "t3.micro"
  asg_min_size         = 1
  asg_max_size         = 2
  asg_desired_capacity = 1
  create_bastion       = true
  ssh_key_name         = var.ssh_key_name

  db_host                  = module.database.db_endpoint
  db_port                  = module.database.db_port
  db_name                  = var.db_name
  db_user                  = var.db_username
  db_password              = random_password.db_password.result
  db_credentials_secret_id = aws_secretsmanager_secret.db_credentials.id
  instance_profile_name    = aws_iam_instance_profile.ec2_profile.name

  depends_on = [module.database, module.alb, aws_iam_instance_profile.ec2_profile]
}
