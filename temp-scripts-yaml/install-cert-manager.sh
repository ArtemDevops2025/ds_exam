#!/bin/bash
# Run on local machine

set -e

MASTER_IP=$(cd /home/a/IT/GroupExam/ds_exam_group/terraform && terraform output -raw k3s_master_ip)
SSH_KEY="ds_exam_key.pem"

echo "=== INSTALLING CERT-MANAGER ==="
echo "Master IP: $MASTER_IP"

# Install cert-manager on the master node
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml"

# Wait for cert-manager to be ready
echo "Waiting for cert-manager to be ready..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager"
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager"
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager"

# Add a delay to allow webhook certificate to be properly set up
echo "Waiting for webhook certificate to be ready..."
sleep 30

echo "Cert-manager installation complete!"
