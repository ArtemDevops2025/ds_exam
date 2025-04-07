#!/bin/bash
#chmod +x apply-elastic-ips.sh
set -e

echo "Applying Elastic IP configuration..."
cd terraform
terraform init
terraform apply -auto-approve

echo "Elastic IPs successfully configured!"
echo "Master IP: $(terraform output -raw k3s_master_ip)"
echo "Worker IPs: $(terraform output -json k3s_worker_ips | jq -r '.[]')"