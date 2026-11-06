#!/usr/bin/env bash
# Rebuilds inventory.ini from the Terraform state (run after every terraform apply / lab restart).
set -euo pipefail
cd "$(dirname "$0")/../terraform"
terraform output -raw ansible_inventory > ../ansible/inventory.ini
echo "inventory.ini refreshed:"; grep -E '^node-' ../ansible/inventory.ini | awk '{print "  "$1, $2, $4}'
