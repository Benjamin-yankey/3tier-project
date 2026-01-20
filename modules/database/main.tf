# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.common_tags.project_name}-db-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.common_tags.project_name}-db-subnet-group"
  })
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier             = "${var.common_tags.project_name}-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  allocated_storage      = var.allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = "appdb"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_security_group_id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = true
  iam_database_authentication_enabled = true

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  tags = merge(var.common_tags, {
    Name = "${var.common_tags.project_name}-rds-instance"
  })
}


