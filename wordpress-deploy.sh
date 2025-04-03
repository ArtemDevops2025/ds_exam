#!/bin/bash
# wordpress-deploy.sh - Automate WordPress deployment to k3s cluster

# Set variables
MASTER_IP="13.36.178.151"
SSH_KEY="ds_exam_key.pem"
LOCAL_YAML_DIR="~/IT/GroupExam/ds_exam_group/kubernetes"
REMOTE_DIR="wordpress"

# Create remote directory and ensure it's empty
ssh -i $SSH_KEY ubuntu@$MASTER_IP "mkdir -p ~/$REMOTE_DIR && rm -f ~/$REMOTE_DIR/*.yaml"

# Transfer all YAML files
scp -i $SSH_KEY $LOCAL_YAML_DIR/*.yaml ubuntu@$MASTER_IP:~/$REMOTE_DIR/

# Apply Kubernetes manifests in the correct order
ssh -i $SSH_KEY ubuntu@$MASTER_IP "cd ~/$REMOTE_DIR && \
  sudo kubectl apply -f namespace.yaml && \
  sudo kubectl apply -f s3-secret.yaml && \
  sudo kubectl apply -f wordpress-pvc.yaml && \
  sudo kubectl apply -f mysql-deployment.yaml && \
  sudo kubectl apply -f wordpress-deployment.yaml && \
  sudo kubectl apply -f wordpress-service.yaml && \
  sudo kubectl apply -f wordpress-loadbalancer.yaml && \
  echo 'Deployment complete! Checking status...' && \
  sudo kubectl get all -n wordpress"

echo "WordPress deployment automation complete!"
echo "Access your WordPress site at http://$MASTER_IP"
