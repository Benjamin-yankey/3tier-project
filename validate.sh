#!/bin/bash
set -e

echo "🔍 Running Terraform validation checks..."

# Format check
echo "1. Checking Terraform formatting..."
terraform fmt -check -recursive || {
  echo "❌ Format check failed. Run 'terraform fmt -recursive' to fix."
  exit 1
}
echo "✅ Format check passed"

# Validation
echo "2. Validating Terraform configuration..."
terraform validate || {
  echo "❌ Validation failed"
  exit 1
}
echo "✅ Validation passed"

# Security scan (if tfsec is installed)
if command -v tfsec &> /dev/null; then
  echo "3. Running security scan with tfsec..."
  tfsec . --minimum-severity MEDIUM || {
    echo "⚠️  Security issues found"
  }
else
  echo "⚠️  tfsec not installed. Install with: brew install tfsec"
fi

# Cost estimation (if infracost is installed)
if command -v infracost &> /dev/null; then
  echo "4. Estimating costs with infracost..."
  infracost breakdown --path .
else
  echo "⚠️  infracost not installed. Install from: https://www.infracost.io/docs/"
fi

echo "✅ All validation checks complete!"
