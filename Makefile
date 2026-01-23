.PHONY: help init plan apply destroy validate format clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	terraform init

validate: ## Validate and format Terraform code
	@./validate.sh

format: ## Format Terraform code
	terraform fmt -recursive

plan: ## Generate Terraform plan
	terraform plan -out=tfplan

apply: ## Apply Terraform changes
	terraform apply tfplan

apply-auto: ## Apply Terraform changes without confirmation
	terraform apply -auto-approve

destroy: ## Destroy all resources
	terraform destroy

destroy-auto: ## Destroy all resources without confirmation
	terraform destroy -auto-approve

clean: ## Clean Terraform files
	rm -rf .terraform .terraform.lock.hcl tfplan

refresh: ## Refresh Terraform state
	terraform refresh

output: ## Show Terraform outputs
	terraform output

state-list: ## List resources in state
	terraform state list

docs: ## Generate module documentation
	@echo "Generating documentation..."
	@terraform-docs markdown table . > TERRAFORM.md

cost: ## Estimate infrastructure costs
	@infracost breakdown --path .
