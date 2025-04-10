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

# Create WordPress config configmap with direct password reference
echo "Creating WordPress config configmap..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
# Get the actual password from the secret (create namespace first if it doesn't exist)
sudo kubectl apply -f ~/$REMOTE_DIR/namespace.yaml
sudo kubectl apply -f ~/$REMOTE_DIR/s3-secret.yaml

# Wait for the secret to be available
echo 'Waiting for mysql-pass secret...'
if ! sudo kubectl get secret mysql-pass -n wordpress &>/dev/null; then
  echo 'Creating mysql-pass secret...'
  echo -n 'wordpress-password' | sudo kubectl create secret generic mysql-pass -n wordpress --from-file=password=/dev/stdin
fi

# Get the password
DB_PASSWORD=\$(sudo kubectl get secret mysql-pass -n wordpress -o jsonpath='{.data.password}' | base64 --decode)

# Create a new wp-config.php with the direct password and debugging enabled
cat > wp-config.php << EOF
<?php
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'wordpress' );
define( 'DB_PASSWORD', '\$DB_PASSWORD' );
define( 'DB_HOST', 'wordpress-mysql' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );

define( 'AUTH_KEY',         'put your unique phrase here' );
define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );
define( 'LOGGED_IN_KEY',    'put your unique phrase here' );
define( 'NONCE_KEY',        'put your unique phrase here' );
define( 'AUTH_SALT',        'put your unique phrase here' );
define( 'SECURE_AUTH_SALT', 'put your unique phrase here' );
define( 'LOGGED_IN_SALT',   'put your unique phrase here' );
define( 'NONCE_SALT',       'put your unique phrase here' );

\\\$table_prefix = 'wp_';

define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', true );

define('WP_HOME', 'http://$MASTER_IP.nip.io');
define('WP_SITEURL', 'http://$MASTER_IP.nip.io');

if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
EOF

# Delete existing configmap if it exists
sudo kubectl delete configmap wordpress-config -n wordpress --ignore-not-found

# Create new configmap
sudo kubectl create configmap wordpress-config -n wordpress --from-file=wp-config.php
rm wp-config.php"

# Check if deployments exist and delete them if they do (clean slate approach)
echo "Checking for existing deployments..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  if sudo kubectl get deployment wordpress-mysql -n wordpress &>/dev/null; then
    echo 'Removing existing MySQL deployment...'
    sudo kubectl delete deployment wordpress-mysql -n wordpress
  fi
  
  if sudo kubectl get deployment wordpress -n wordpress &>/dev/null; then
    echo 'Removing existing WordPress deployment...'
    sudo kubectl delete deployment wordpress -n wordpress
  fi
"

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
  sudo kubectl apply -f wordpress-ingress.yaml"

# Fix MySQL service selector to match pod labels
echo "Fixing MySQL service selector..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  sudo kubectl patch svc wordpress-mysql -n wordpress --type=json -p='[{\"op\": \"replace\", \"path\": \"/spec/selector\", \"value\": {\"app\": \"wordpress-mysql\", \"tier\": \"mysql\"}}]'
"

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'Waiting for MySQL...'
  sudo kubectl wait --for=condition=ready pod -l tier=mysql -n wordpress --timeout=120s || true
  
  echo 'Waiting for WordPress...'
  sudo kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress --timeout=120s || true
"

# Test database connectivity
echo "Testing database connectivity..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  # Wait a bit longer for MySQL to initialize
  echo 'Waiting for MySQL to initialize...'
  sleep 30
  
  # Test connection from a WordPress pod
  WORDPRESS_POD=\$(sudo kubectl get pod -l app=wordpress -n wordpress -o jsonpath='{.items[0].metadata.name}')
  echo 'Testing connection from WordPress pod: '\$WORDPRESS_POD
  sudo kubectl exec \$WORDPRESS_POD -n wordpress -- bash -c 'mysql -h wordpress-mysql -u wordpress -p\$WORDPRESS_DB_PASSWORD -e \"SHOW DATABASES;\"' || echo 'Database connection failed'
  
  # If connection fails, check MySQL logs
  if [ \$? -ne 0 ]; then
    MYSQL_POD=\$(sudo kubectl get pod -l tier=mysql -n wordpress -o jsonpath='{.items[0].metadata.name}')
    echo 'MySQL pod logs:'
    sudo kubectl logs \$MYSQL_POD -n wordpress
  fi
"

# Check pod logs for errors
echo "Checking WordPress pod logs for errors..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  WORDPRESS_POD=\$(sudo kubectl get pod -l app=wordpress -n wordpress -o jsonpath='{.items[0].metadata.name}')
  echo 'WordPress pod: '\$WORDPRESS_POD
  sudo kubectl logs -n wordpress \$WORDPRESS_POD | tail -n 50
"

# Check deployment status
echo "Checking deployment status..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get all -n wordpress"

# Verify ingress is working
echo "Verifying ingress deployment..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get ingress -n wordpress"

#echo "WordPress deployment automation complete!"
echo "Access your WordPress site at:"
echo "- Load Balancer: http://$MASTER_IP"
echo "- Ingress: http://$MASTER_IP.nip.io"
