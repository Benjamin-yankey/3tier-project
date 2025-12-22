locals {
  common_tags = {
    project_name = var.project_name
    environment  = var.environment
    owner_name   = var.owner_name
  }
}


# Module 1: Networking
module "networking" {
  source = "./modules/networking"

  vpc_cidr    = var.vpc_cidr
  common_tags = local.common_tags

}

# Module 2: Security Groups
module "security" {
  source = "./modules/security"

  vpc_id       = module.networking.vpc_id
  project_name = var.project_name
  environment  = var.environment
  owner_name   = var.owner_name
}

# Module 3: Application Load Balancer
module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  owner_name            = var.owner_name
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security.alb_sg_id
}

# Module 4: Compute
module "compute" {
  source                    = "./modules/compute"
  common_tags               = local.common_tags
  private_subnet_ids        = module.networking.private_app_subnet_ids
  app_security_group_id     = module.security.app_sg_id
  target_group_arn          = module.alb.target_group_arn
  instance_type             = "t3.micro"
  asg_min_size              = 2
  asg_max_size              = 5
  asg_desired_capacity      = 2
  public_subnet_ids         = module.networking.public_subnet_ids
  bastion_security_group_id = module.security.bastion_sg_id
  create_bastion            = true
  ssh_key_name              = var.ssh_key_name
  private_app_subnet_ids    = module.networking.private_app_subnet_ids

  db_host     = module.database.db_endpoint
  db_port     = module.database.db_port
  db_password = var.db_password
  db_name     = var.db_name
  db_user     = var.db_user

}

# Module 5: Database
module "database" {
  source                = "./modules/database"
  common_tags           = local.common_tags
  private_db_subnet_ids = module.networking.private_db_subnet_ids
  db_security_group_id  = module.security.db_sg_id
  db_username           = var.db_username
  db_password           = var.db_password
  db_instance_class     = "db.t3.micro"
  allocated_storage     = 20
}
