#!/bin/bash
# Restore the secret from deletion
aws secretsmanager restore-secret --secret-id tier3-app-dev-db-password

echo "Secret restored. Now run: terraform apply"
