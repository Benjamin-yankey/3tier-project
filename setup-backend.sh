#!/bin/bash
set -e

PROJECT_NAME="3tier-app"
REGION="eu-west-1"
BUCKET_NAME="${PROJECT_NAME}-terraform-state-$(date +%s)"
TABLE_NAME="terraform-state-locks"

echo "Setting up Terraform remote state backend..."

# Create S3 bucket for state
echo "Creating S3 bucket: $BUCKET_NAME"
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION"

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
echo "Creating DynamoDB table: $TABLE_NAME"
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo "✅ Backend setup complete!"
echo "Update backend.tf with bucket name: $BUCKET_NAME"
