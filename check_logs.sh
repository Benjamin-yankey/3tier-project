#!/bin/bash

# Get instance IDs from ASG
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw asg_name) \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text)

echo "Found instances: $INSTANCE_IDS"
echo ""

for INSTANCE_ID in $INSTANCE_IDS; do
  echo "=== Logs for $INSTANCE_ID ==="
  
  # Get private IP
  PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)
  
  echo "Private IP: $PRIVATE_IP"
  echo ""
  
  # Get bastion IP
  BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null)
  
  if [ -n "$BASTION_IP" ]; then
    echo "SSH via bastion: ssh -J ubuntu@$BASTION_IP ubuntu@$PRIVATE_IP"
    echo ""
    echo "App log:"
    ssh -o StrictHostKeyChecking=no -J ubuntu@$BASTION_IP ubuntu@$PRIVATE_IP "tail -50 /opt/todo-app/app.log"
    echo ""
    echo "Cloud-init log:"
    ssh -o StrictHostKeyChecking=no -J ubuntu@$BASTION_IP ubuntu@$PRIVATE_IP "tail -50 /var/log/cloud-init-output.log"
  else
    echo "Use AWS Systems Manager Session Manager:"
    echo "aws ssm start-session --target $INSTANCE_ID"
    echo ""
    echo "Then run:"
    echo "  tail -50 /opt/todo-app/app.log"
    echo "  tail -50 /var/log/cloud-init-output.log"
  fi
  
  echo ""
  echo "================================"
  echo ""
done
