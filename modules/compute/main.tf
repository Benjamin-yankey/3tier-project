# ============================================================================
# DATA SOURCES
# ============================================================================

# Fetch the latest Ubuntu 22.04 LTS AMI from Canonical (official Ubuntu publisher)
# This ensures we always use the most recent patched version for security
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID

  # Filter for Ubuntu 22.04 Jammy Jellyfish with SSD storage
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  # Ensure we get HVM (Hardware Virtual Machine) virtualization type
  # HVM provides better performance than paravirtualization
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get the current AWS region dynamically
# Used in user_data script to retrieve secrets from the correct region
data "aws_region" "current" {}

# ============================================================================
# USER DATA SCRIPT
# ============================================================================

# Bootstrap script that runs on EC2 instance launch
# This script installs dependencies, clones the app, configures environment,
# and starts the Node.js todo application
locals {
  user_data = <<-EOF
#!/usr/bin/env bash
# Exit immediately if any command fails (fail-fast approach)
set -e

############################
# SYSTEM SETUP
############################
# Update package lists and install required system utilities:
# - curl: for downloading files and making HTTP requests
# - git: for cloning the application repository
# - awscli: for retrieving secrets from AWS Secrets Manager
# - jq: for parsing JSON responses from AWS CLI
# - netcat: for checking database connectivity
apt-get update -y
apt-get install -y curl git awscli jq netcat

############################
# INSTALL NODE.JS 18
############################
# Add NodeSource repository and install Node.js 18 LTS
# The todo app requires Node.js to run
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

############################
# APP DIRECTORY
############################
# Create application directory in /opt (standard location for third-party apps)
# Exit with error if directory creation or navigation fails
mkdir -p /opt/todo-app
cd /opt/todo-app || { echo "Cannot cd to /opt/todo-app"; exit 1; }

############################
# CLONE APP FROM GITHUB
############################
# Clone the todo application repository into current directory (.)
# Then install all Node.js dependencies defined in package.json
git clone https://github.com/Asheryram/todo-app.git .
npm install

############################
# RETRIEVE CREDENTIALS FROM SECRETS MANAGER
############################
# Securely fetch database credentials from AWS Secrets Manager
# This avoids hardcoding sensitive credentials in the code
CREDENTIALS=$(aws secretsmanager get-secret-value \
  --secret-id ${var.db_credentials_secret_id} \
  --region ${data.aws_region.current.name} \
  --query SecretString \
  --output text)

# Parse JSON response to extract username and password
DB_USER=$(echo $CREDENTIALS | jq -r '.username')
DB_PASSWORD=$(echo $CREDENTIALS | jq -r '.password')

############################
# EXPORT ENV VARIABLES
############################
# Configure environment variables required by the Node.js application
# Extract hostname without port from DB endpoint (RDS endpoint includes :3306)
DB_HOST_ONLY=$(echo "${var.db_host}" | cut -d':' -f1)

# Create a shell script in /etc/profile.d/ to persist environment variables
# This ensures variables are available for all users and sessions
cat <<ENV > /etc/profile.d/todo-env.sh
export PORT=3000
export DB_HOST="$DB_HOST_ONLY"
export DB_USER="$DB_USER"
export DB_PASSWORD="$DB_PASSWORD"
export DB_NAME="${var.db_name}"
export DB_PORT="${var.db_port}"
ENV

# Load the environment variables into the current shell session
source /etc/profile.d/todo-env.sh

############################
# WAIT FOR DATABASE TO BE READY
############################
# Implement retry logic to wait for RDS database to become available
# RDS can take several minutes to initialize after creation
echo "Waiting for database to be reachable..."

# Extract hostname without port (in case it's included)
DB_HOST_ONLY=$(echo "${var.db_host}" | cut -d':' -f1)

max_attempts=60  # Maximum 5 minutes (60 attempts * 5 seconds)
attempt=1

# Use netcat (nc) to check if database port is open and accepting connections
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

# Start Node.js app in background using nohup (no hangup)
# Redirect stdout and stderr to app.log for debugging
# The & runs the process in background
nohup node server.js > app.log 2>&1 &
APP_PID=$!  # Capture the process ID of the background job
echo $APP_PID > /tmp/todo-app.pid  # Save PID for later management

############################
# WAIT AND CONFIRM APP IS RUNNING
############################
# Verify the application started successfully by checking the /health endpoint
# This prevents the instance from being marked healthy if the app failed to start
echo "Waiting up to 30 seconds for app to become healthy..."

max_health_attempts=30
health_attempt=1
HEALTH_OK=false

# Poll the health endpoint until it returns "OK" or we reach max attempts
while (( health_attempt <= max_health_attempts )); do
  if curl -s --fail http://localhost:3000/health | grep -q "OK"; then
    HEALTH_OK=true
    break
  fi
  echo "Health check attempt $health_attempt/$max_health_attempts failed. Retrying in 1s..."
  sleep 1
  ((health_attempt++))
done

# Report success or failure with helpful debugging information
if $HEALTH_OK; then
  echo "✅ App started successfully (PID $APP_PID)"
  echo "Logs are in /opt/todo-app/app.log"
else
  echo "❌ App failed to become healthy after $max_health_attempts seconds"
  echo "Last 20 lines of app.log:"
  tail -n 20 app.log
  exit 1  # Exit with error to prevent unhealthy instance from serving traffic
fi

EOF
}

# ============================================================================
# LAUNCH TEMPLATE
# ============================================================================

# Launch Template defines the configuration for EC2 instances in the ASG
# It's like a blueprint that ASG uses to launch new instances
resource "aws_launch_template" "app" {
  name_prefix   = "${var.common_tags.project_name}-${var.common_tags.environment}-lt-"
  description   = "Launch template for ${var.common_tags.project_name} application servers"
  image_id      = data.aws_ami.ubuntu.id  # Use the Ubuntu AMI we fetched earlier
  instance_type = var.instance_type        # Instance size (e.g., t3.micro)

  # Attach security group to control inbound/outbound traffic
  vpc_security_group_ids = [var.app_security_group_id]

  # Base64 encode the user_data script (AWS requirement)
  user_data = base64encode(local.user_data)

  # Enable detailed CloudWatch monitoring (1-minute intervals instead of 5-minute)
  monitoring {
    enabled = true
  }

  # Attach IAM role to allow instance to access AWS services (Secrets Manager, etc.)
  iam_instance_profile {
    name = var.instance_profile_name
  }

  # Apply tags to instances launched from this template
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.common_tags.project_name}-${var.common_tags.environment}-app-server"
    }
  }
}

# ============================================================================
# AUTO SCALING GROUP
# ============================================================================

# ASG automatically maintains the desired number of healthy instances
# It can scale up/down based on demand and replaces unhealthy instances
resource "aws_autoscaling_group" "app" {
  name                      = "${var.common_tags.project_name}-${var.common_tags.environment}-asg"
  vpc_zone_identifier       = var.private_app_subnet_ids  # Deploy across multiple AZs for HA
  target_group_arns         = [var.target_group_arn]      # Register instances with ALB target group
  health_check_type         = "ELB"                       # Use ALB health checks (more reliable than EC2)
  health_check_grace_period = 300                         # Wait 5 minutes before checking health (app startup time)

  # Define scaling boundaries
  desired_capacity = var.asg_desired_capacity  # Target number of instances
  min_size         = var.asg_min_size          # Minimum instances (always running)
  max_size         = var.asg_max_size          # Maximum instances (scale limit)

  # Reference the launch template for instance configuration
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"  # Always use the latest version of the template
  }

  # Enable CloudWatch metrics for monitoring ASG behavior
  # These metrics help track scaling activities and instance states
  enabled_metrics = [
    "GroupDesiredCapacity",      # Target number of instances
    "GroupInServiceInstances",   # Healthy instances serving traffic
    "GroupMaxSize",              # Maximum capacity
    "GroupMinSize",              # Minimum capacity
    "GroupPendingInstances",     # Instances being launched
    "GroupStandbyInstances",     # Instances in standby state
    "GroupTerminatingInstances", # Instances being terminated
    "GroupTotalInstances"        # Total instances in all states
  ]
}

# ============================================================================
# BASTION HOST (OPTIONAL)
# ============================================================================

# Bastion host (jump box) provides secure SSH access to private instances
# Only created if var.create_bastion is true
resource "aws_instance" "bastion" {
  count                  = var.create_bastion ? 1 : 0  # Conditional creation
  ami                    = data.aws_ami.ubuntu.id      # Same Ubuntu AMI as app servers
  instance_type          = "t3.micro"                  # Small instance (bastion doesn't need much power)
  subnet_id              = var.public_subnet_ids[0]    # Deploy in public subnet for internet access
  vpc_security_group_ids = [var.bastion_security_group_id]  # Security group allows SSH from specific IPs
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null  # SSH key for authentication

  # Assign public IP so we can SSH from the internet
  associate_public_ip_address = true

  # Simple user data script to install Apache web server
  # This provides a visual confirmation that the bastion is running
  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2
              echo "<h1>Bastion Host - ${var.common_tags.project_name}</h1>" > /var/www/html/index.html
              systemctl start apache2
              systemctl enable apache2
              EOF
  )

  # IMDSv2 configuration for enhanced security
  # Requires session tokens to access instance metadata (prevents SSRF attacks)
  metadata_options {
    http_endpoint               = "enabled"  # Enable metadata service
    http_tokens                 = "required" # Require IMDSv2 (more secure than IMDSv1)
    http_put_response_hop_limit = 1          # Limit metadata access to the instance itself
  }

  # Configure root EBS volume
  root_block_device {
    volume_type           = "gp3"  # General Purpose SSD (latest generation, better performance)
    volume_size           = 10     # 10 GB is sufficient for bastion host
    delete_on_termination = true   # Clean up volume when instance is terminated
    encrypted             = true   # Encrypt data at rest for security compliance
  }

  # Tag the bastion instance for identification and cost tracking
  tags = {
    Name = "${var.common_tags.project_name}-${var.common_tags.environment}-bastion"
  }
}
