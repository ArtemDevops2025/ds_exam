#!/bin/bash
# cleanup-kubernetes.sh

MASTER_IP=$(cd terraform && terraform output -raw k3s_master_ip)
SSH_KEY="ds_exam_key.pem"

echo "Cleaning up Kubernetes deployment..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  # Remove finalizers from all resources in wordpress namespace
  for resource in \$(sudo kubectl get all,ingress,pvc,secret -n wordpress -o name); do
    echo \"Removing finalizers from \$resource\"
    sudo kubectl patch \$resource -n wordpress --type=json -p='[{\"op\":\"remove\",\"path\":\"/metadata/finalizers\"}]' 2>/dev/null || true
  done

  # Force delete wordpress namespace
  sudo kubectl delete namespace wordpress --force --grace-period=0

  # Remove finalizers from cert-manager resources
  for resource in \$(sudo kubectl get all,clusterissuer -n cert-manager -o name 2>/dev/null); do
    echo \"Removing finalizers from \$resource\"
    sudo kubectl patch \$resource -n cert-manager --type=json -p='[{\"op\":\"remove\",\"path\":\"/metadata/finalizers\"}]' 2>/dev/null || true
  done

  # Force delete cert-manager namespace
  sudo kubectl delete namespace cert-manager --force --grace-period=0

  # Wait for namespaces to be fully deleted
  echo 'Waiting for namespaces to be deleted...'
  while sudo kubectl get namespace wordpress 2>/dev/null || sudo kubectl get namespace cert-manager 2>/dev/null; do
    echo 'Still waiting...'
    sleep 5
  done

  echo 'Cleanup complete!'
"