# Create secret for database credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-${var.environment}-db-credentials"
  description             = "RDS database credentials"
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-db-credentials"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Generate random password
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store credentials as JSON
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
  })
}

# Data source to retrieve credentials
data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id  = aws_secretsmanager_secret.db_credentials.id
  depends_on = [aws_secretsmanager_secret_version.db_credentials]
}
