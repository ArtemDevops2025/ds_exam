#!/bin/bash
# wordpress-deploy.sh - Automate WordPress deployment to k3s cluster New version!!!!!!!



MASTER_IP=$(cd terraform && terraform output -raw k3s_master_ip)
SSH_KEY="ds_exam_key.pem"
# Use absolute path without tilde
LOCAL_YAML_DIR="/home/a/IT/GroupExam/ds_exam_group/kubernetes"
REMOTE_DIR="wordpress"

echo "Starting WordPress deployment to K3s cluster at $MASTER_IP"

# Create remote directory and ensure it's empty
ssh -i $SSH_KEY ubuntu@$MASTER_IP "mkdir -p ~/$REMOTE_DIR && rm -f ~/$REMOTE_DIR/*.yaml"

# Transfer all YAML files
echo "Transferring Kubernetes manifests to master node..."
scp -i $SSH_KEY $LOCAL_YAML_DIR/*.yaml ubuntu@$MASTER_IP:~/$REMOTE_DIR/

# Update the ingress host with the current master IP
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sed -i 's/host: \".*\"/host: \"$MASTER_IP.nip.io\"/' ~/$REMOTE_DIR/wordpress-ingress.yaml"

# Apply Kubernetes manifests in the correct order
echo "Applying Kubernetes manifests..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "cd ~/$REMOTE_DIR && \
  sudo kubectl apply -f namespace.yaml && \
  sudo kubectl apply -f s3-secret.yaml && \
  sudo kubectl apply -f wordpress-pvc.yaml && \
  sudo kubectl apply -f mysql-deployment.yaml && \
  sudo kubectl apply -f wordpress-deployment.yaml && \
  sudo kubectl apply -f wordpress-service.yaml && \
  sudo kubectl apply -f wordpress-loadbalancer.yaml && \
  sudo kubectl apply -f wordpress-ingress.yaml && \
  echo 'Deployment complete! Checking status...' && \
  sudo kubectl get all -n wordpress"

# Verify ingress is working
echo "Verifying ingress deployment..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get ingress -n wordpress"

echo "WordPress deployment automation complete!"
echo "Access your WordPress site at:"
echo "- Load Balancer: http://$MASTER_IP"
echo "- Ingress: http://$MASTER_IP.nip.io"
