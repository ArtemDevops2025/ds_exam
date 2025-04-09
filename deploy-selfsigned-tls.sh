#!/bin/bash
# Run on local machine

set -e

MASTER_IP=$(cd /home/a/IT/GroupExam/ds_exam_group/terraform && terraform output -raw k3s_master_ip)
SSH_KEY="ds_exam_key.pem"

echo "=== DEPLOYING SELF-SIGNED TLS FOR WORDPRESS ==="
echo "Master IP: $MASTER_IP"

# Step 1: Install cert-manager if not already installed
if ! ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get namespace cert-manager &>/dev/null"; then
  echo "Installing cert-manager..."
  ./install-cert-manager.sh
else
  echo "Cert-manager already installed, skipping..."
fi

# Step 2: Apply the self-signed issuer
echo "Applying self-signed ClusterIssuer..."
sed "s/MASTER_IP/$MASTER_IP/g" selfsigned-issuer.yaml > /tmp/selfsigned-issuer.yaml
scp -i $SSH_KEY /tmp/selfsigned-issuer.yaml ubuntu@$MASTER_IP:/home/ubuntu/
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl apply -f /home/ubuntu/selfsigned-issuer.yaml"

# Step 3: Create the certificate
echo "Creating self-signed certificate..."
sed "s/MASTER_IP/$MASTER_IP/g" wordpress-selfsigned-certificate.yaml > /tmp/wordpress-selfsigned-certificate.yaml
scp -i $SSH_KEY /tmp/wordpress-selfsigned-certificate.yaml ubuntu@$MASTER_IP:/home/ubuntu/
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl apply -f /home/ubuntu/wordpress-selfsigned-certificate.yaml"

# Step 4: Update the ingress to use TLS
echo "Updating ingress to use TLS..."
sed "s/MASTER_IP/$MASTER_IP/g" wordpress-tls-ingress.yaml > /tmp/wordpress-tls-ingress.yaml
scp -i $SSH_KEY /tmp/wordpress-tls-ingress.yaml ubuntu@$MASTER_IP:/home/ubuntu/
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl apply -f /home/ubuntu/wordpress-tls-ingress.yaml"

# Step 5: Verify certificate issuance
echo "Verifying certificate issuance..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get certificate -n wordpress"

echo "Self-signed TLS deployment complete!"
echo "Access your WordPress site securely at: https://$MASTER_IP.nip.io"
echo "Note: Your browser will show a security warning because the certificate is self-signed."
