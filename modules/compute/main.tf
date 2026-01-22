# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_region" "current" {}

# User data script for web servers
locals {
  user_data = <<-EOF
#!/usr/bin/env bash
set -e

############################
# SYSTEM SETUP
############################
apt-get update -y
apt-get install -y curl git awscli jq netcat

############################
# INSTALL NODE.JS 18
############################
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

############################
# APP DIRECTORY
############################
mkdir -p /opt/todo-app
cd /opt/todo-app || { echo "Cannot cd to /opt/todo-app"; exit 1; }

############################
# CLONE APP FROM GITHUB
############################
git clone https://github.com/Asheryram/todo-app.git .
npm install

############################
# RETRIEVE CREDENTIALS FROM SECRETS MANAGER
############################
CREDENTIALS=$(aws secretsmanager get-secret-value \
  --secret-id ${var.db_credentials_secret_id} \
  --region ${data.aws_region.current.name} \
  --query SecretString \
  --output text)

DB_USER=$(echo $CREDENTIALS | jq -r '.username')
DB_PASSWORD=$(echo $CREDENTIALS | jq -r '.password')

############################
# EXPORT ENV VARIABLES
############################
# Extract hostname without port from DB endpoint
DB_HOST_ONLY=$(echo "${var.db_host}" | cut -d':' -f1)

cat <<ENV > /etc/profile.d/todo-env.sh
export PORT=3000
export DB_HOST="$DB_HOST_ONLY"
export DB_USER="$DB_USER"
export DB_PASSWORD="$DB_PASSWORD"
export DB_NAME="${var.db_name}"
export DB_PORT="${var.db_port}"
ENV

source /etc/profile.d/todo-env.sh

############################
# WAIT FOR DATABASE TO BE READY
############################
echo "Waiting for database to be reachable..."

# Extract hostname without port
DB_HOST_ONLY=$(echo "${var.db_host}" | cut -d':' -f1)

max_attempts=60
attempt=1

until nc -z $DB_HOST_ONLY ${var.db_port}; do
  if (( attempt == max_attempts )); then
    echo "Error: Database not reachable after $max_attempts attempts"
    exit 1
  fi
  echo "Attempt $attempt/$max_attempts: Waiting for DB at $DB_HOST_ONLY:${var.db_port}..."
  sleep 5
  ((attempt++))
done

echo "Database is reachable!"

############################
# START APPLICATION
############################
cd /opt/todo-app
echo "Starting Node.js application..."

nohup node server.js > app.log 2>&1 &
APP_PID=$!
echo $APP_PID > /tmp/todo-app.pid

############################
# WAIT AND CONFIRM APP IS RUNNING
############################
echo "Waiting up to 30 seconds for app to become healthy..."

max_health_attempts=30
health_attempt=1
HEALTH_OK=false

while (( health_attempt <= max_health_attempts )); do
  if curl -s --fail http://localhost:3000/health | grep -q "OK"; then
    HEALTH_OK=true
    break
  fi
  echo "Health check attempt $health_attempt/$max_health_attempts failed. Retrying in 1s..."
  sleep 1
  ((health_attempt++))
done

if $HEALTH_OK; then
  echo "✅ App started successfully (PID $APP_PID)"
  echo "Logs are in /opt/todo-app/app.log"
else
  echo "❌ App failed to become healthy after $max_health_attempts seconds"
  echo "Last 20 lines of app.log:"
  tail -n 20 app.log
  exit 1
fi

EOF
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.common_tags.project_name}-${var.common_tags.environment}-lt-"
  description   = "Launch template for ${var.common_tags.project_name} application servers"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [var.app_security_group_id]

  user_data = base64encode(local.user_data)

  monitoring {
    enabled = true
  }

  iam_instance_profile {
    name = var.instance_profile_name
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.common_tags.project_name}-${var.common_tags.environment}-app-server"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                      = "${var.common_tags.project_name}-${var.common_tags.environment}-asg"
  vpc_zone_identifier       = var.private_app_subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  desired_capacity = var.asg_desired_capacity
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]
}

# Bastion Host (Optional)
resource "aws_instance" "bastion" {
  count                  = var.create_bastion ? 1 : 0
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.bastion_security_group_id]
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null

  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2
              echo "<h1>Bastion Host - ${var.common_tags.project_name}</h1>" > /var/www/html/index.html
              systemctl start apache2
              systemctl enable apache2
              EOF
  )

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = "${var.common_tags.project_name}-${var.common_tags.environment}-bastion"
  }
}
