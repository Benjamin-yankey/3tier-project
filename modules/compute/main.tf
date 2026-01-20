# Data source for Amazon Linux 2 AMI
data "aws_ssm_parameter" "amzn2" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}


# User data script for web servers
locals {
  user_data = <<-EOF
#!/bin/bash
set -e

############################
# SYSTEM UPDATE
############################
yum update -y

############################
# INSTALL REQUIRED PACKAGES
############################
yum install -y curl git

############################
# INSTALL NODE.JS 18
############################
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

############################
# APP DIRECTORY
############################
mkdir -p /opt/app
cd /opt/app

############################
# CLONE APP FROM GITHUB
############################
git clone https://github.com/Benjamin-yankey/app.git .
npm install

############################
# ENVIRONMENT VARIABLES
############################
cat <<ENV > /etc/profile.d/app-env.sh
export PORT=3000
export DB_HOST="${var.db_host}"
export DB_USER="${var.db_user}"
export DB_PASSWORD="${var.db_password}"
export DB_NAME="${var.db_name}"
export DB_PORT="${var.db_port}"
ENV

chmod +x /etc/profile.d/app-env.sh
source /etc/profile.d/app-env.sh

############################
# START APPLICATION
############################
export PORT=3000
export DB_HOST="${var.db_host}"
export DB_USER="${var.db_user}"
export DB_PASSWORD="${var.db_password}"
export DB_NAME="${var.db_name}"
export DB_PORT="${var.db_port}"

nohup node Node.js > /var/log/app.log 2>&1 &

EOF
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.common_tags.project_name}-${var.common_tags.environment}-lt-"
  description   = "Launch template for ${var.common_tags.project_name} application servers"
  image_id      = data.aws_ssm_parameter.amzn2.value
  instance_type = var.instance_type

  vpc_security_group_ids = [var.app_security_group_id]

  user_data = base64encode(local.user_data)

  monitoring {
    enabled = true
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
  health_check_grace_period = 600

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
  ami                    = data.aws_ssm_parameter.amzn2.value
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.bastion_security_group_id]
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null

  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              echo "<h1>Bastion Host - ${var.common_tags.project_name}</h1>" > /var/www/html/index.html
              systemctl start httpd
              systemctl enable httpd
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
