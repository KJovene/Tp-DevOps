#!/usr/bin/env bash
set -euo pipefail

terraform_dir="../terraform/environments/staging"
output_file="inventory.yml"

terraform -chdir="$terraform_dir" workspace select dev >/dev/null
terraform -chdir="$terraform_dir" output -raw ansible_inventory > "$output_file"
ansible-inventory -i "$output_file" --graph