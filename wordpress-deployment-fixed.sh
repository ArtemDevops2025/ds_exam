#!/bin/bash
# improved-deploy.sh - Complete WordPress deployment with TLS

MASTER_IP=$(cd terraform && terraform output -raw k3s_master_ip)
SSH_KEY="ds_exam_key.pem"
LOCAL_YAML_DIR="/home/a/IT/GroupExam/ds_exam_group/kubernetes"
REMOTE_DIR="wordpress"
EMAIL="schmakov1@gmail.com"

echo "===== STARTING COMPLETE WORDPRESS DEPLOYMENT WITH TLS ====="
echo "Master IP: $MASTER_IP"

# STEP 1: Clean up previous deployments
echo "===== STEP 1: CLEANING UP PREVIOUS DEPLOYMENTS ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'Removing finalizers from wordpress resources...'
  for resource in \$(sudo kubectl get all,ingress,pvc,secret -n wordpress -o name 2>/dev/null); do
    sudo kubectl patch \$resource -n wordpress --type=json -p='[{\"op\":\"remove\",\"path\":\"/metadata/finalizers\"}]' 2>/dev/null || true
  done

  echo 'Force deleting wordpress namespace...'
  sudo kubectl delete namespace wordpress --force --grace-period=0 2>/dev/null || true

  echo 'Removing finalizers from cert-manager resources...'
  for resource in \$(sudo kubectl get all,clusterissuer -n cert-manager -o name 2>/dev/null); do
    sudo kubectl patch \$resource -n cert-manager --type=json -p='[{\"op\":\"remove\",\"path\":\"/metadata/finalizers\"}]' 2>/dev/null || true
  done

  echo 'Force deleting cert-manager namespace...'
  sudo kubectl delete namespace cert-manager --force --grace-period=0 2>/dev/null || true

  echo 'Waiting for namespaces to be fully deleted...'
  while sudo kubectl get namespace wordpress 2>/dev/null || sudo kubectl get namespace cert-manager 2>/dev/null; do
    echo 'Still waiting...'
    sleep 5
  done
"
# STEP 2: Create remote directories and transfer configuration files
echo "===== STEP 2: PREPARING CONFIGURATION FILES ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "mkdir -p ~/$REMOTE_DIR/cert-manager"

# Transfer WordPress YAML files
echo "Transferring WordPress manifests..."
scp -i $SSH_KEY $LOCAL_YAML_DIR/*.yaml ubuntu@$MASTER_IP:~/$REMOTE_DIR/

# Transfer cert-manager YAML files
echo "Transferring cert-manager manifests..."
scp -i $SSH_KEY $LOCAL_YAML_DIR/cert-manager/*.yaml ubuntu@$MASTER_IP:~/$REMOTE_DIR/cert-manager/

# Update configurations with master IP
echo "Updating configurations with master IP: $MASTER_IP..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  sed -i 's/host: \".*\"/host: \"$MASTER_IP.nip.io\"/' ~/$REMOTE_DIR/wordpress-ingress.yaml
  sed -i 's/- hosts:.*/- hosts:\\n    - $MASTER_IP.nip.io/' ~/$REMOTE_DIR/wordpress-ingress-tls.yaml
  sed -i 's/- host:.*/- host: $MASTER_IP.nip.io/' ~/$REMOTE_DIR/wordpress-ingress-tls.yaml
  
  # Fix ingress backend service name
  sed -i 's/name: wordpress/name: wordpress-lb/' ~/$REMOTE_DIR/wordpress-ingress.yaml
"
# STEP 3: Check and configure ingress controller
echo "===== STEP 3: CHECKING INGRESS CONTROLLER ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  if ! sudo kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller | grep Running; then
    echo 'Ingress controller not found or not running. Installing...'
    sudo kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    echo 'Waiting for ingress controller to be ready...'
    sudo kubectl -n ingress-nginx wait --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=180s
  else
    echo 'Ingress controller is running.'
  fi
  
  # Ensure ingress controller has proper configuration
  cat > ~/ingress-config-patch.yaml << EOF
data:
  use-forwarded-headers: \"true\"
  preserve-host: \"true\"
  proxy-host-header: \"true\"
  server-snippet: |
    location ~ /.well-known/acme-challenge/ {
      proxy_set_header Host \\\$host;
      proxy_pass http://\\\$service_name.\\\$namespace.svc.cluster.local:8089;
      proxy_set_header X-Forwarded-For \\\$remote_addr;
    }
EOF
  sudo kubectl patch configmap ingress-nginx-controller -n ingress-nginx --patch-file ~/ingress-config-patch.yaml || true
  sudo kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
  echo 'Waiting for ingress controller to restart...'
  sudo kubectl -n ingress-nginx wait --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=180s
"
# STEP 4: Deploy WordPress (without TLS first)
echo "===== STEP 4: DEPLOYING WORDPRESS (WITHOUT TLS) ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  # Apply WordPress manifests in order
  sudo kubectl apply -f ~/$REMOTE_DIR/namespace.yaml
  sudo kubectl apply -f ~/$REMOTE_DIR/s3-secret.yaml
  sudo kubectl apply -f ~/$REMOTE_DIR/wordpress-pvc.yaml
  sudo kubectl apply -f ~/$REMOTE_DIR/mysql-deployment.yaml
  
  # Wait for MySQL to be ready
  echo 'Waiting for MySQL to be ready...'
  sudo kubectl -n wordpress wait --for=condition=ready pod -l tier=mysql --timeout=180s
  
  sudo kubectl apply -f ~/$REMOTE_DIR/wordpress-deployment.yaml
  sudo kubectl apply -f ~/$REMOTE_DIR/wordpress-service.yaml
  sudo kubectl apply -f ~/$REMOTE_DIR/wordpress-loadbalancer.yaml
  
  # Wait for WordPress to be ready
  echo 'Waiting for WordPress to be ready...'
  sudo kubectl -n wordpress wait --for=condition=ready pod -l app=wordpress --timeout=180s
"
# STEP 5: Create proper WordPress ConfigMap and apply correct ingress
echo "===== STEP 5: CREATING PROPER WORDPRESS CONFIG AND INGRESS ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'Creating proper WordPress ConfigMap...'
  cat > ~/wordpress-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: wordpress-config
  namespace: wordpress
data:
  wp-config.php: |
    <?php
    define('DB_NAME', 'wordpress');
    define('DB_USER', 'wordpress');
    define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD'));
    define('DB_HOST', 'wordpress-mysql');
    define('DB_CHARSET', 'utf8');
    define('DB_COLLATE', '');

    define('AUTH_KEY',         'put your unique phrase here');
    define('SECURE_AUTH_KEY',  'put your unique phrase here');
    define('LOGGED_IN_KEY',    'put your unique phrase here');
    define('NONCE_KEY',        'put your unique phrase here');
    define('AUTH_SALT',        'put your unique phrase here');
    define('SECURE_AUTH_SALT', 'put your unique phrase here');
    define('LOGGED_IN_SALT',   'put your unique phrase here');
    define('NONCE_SALT',       'put your unique phrase here');

    \$table_prefix = 'wp_';
    define('WP_DEBUG', false);

    if (!defined('ABSPATH'))
        define('ABSPATH', dirname(__FILE__) . '/');

    // S3 configuration for uploads
    define('S3_UPLOADS_BUCKET', getenv('S3_BUCKET'));
    define('S3_UPLOADS_REGION', getenv('S3_REGION'));
    define('S3_UPLOADS_KEY', getenv('S3_ACCESS_KEY'));
    define('S3_UPLOADS_SECRET', getenv('S3_SECRET_KEY'));
    define('S3_UPLOADS_BUCKET_URL', 'https://'.getenv('S3_BUCKET').'.s3.'.getenv('S3_REGION').'.amazonaws.com');

    require_once(ABSPATH . 'wp-settings.php');
EOF
  sudo kubectl apply -f ~/wordpress-config.yaml
  sudo kubectl rollout restart deployment wordpress -n wordpress
  echo 'Waiting for WordPress to restart...'
  sudo kubectl -n wordpress wait --for=condition=ready pod -l app=wordpress --timeout=180s
  
  # Create a consistent ingress with the correct name
  cat > ~/wordpress-ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress-ingress
  namespace: wordpress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: \"false\"
spec:
  ingressClassName: nginx
  rules:
  - host: \"$MASTER_IP.nip.io\"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wordpress-lb
            port:
              number: 80
EOF
  sudo kubectl apply -f ~/wordpress-ingress.yaml
  
  # Deploy PhpMyAdmin
  echo 'Deploying PhpMyAdmin...'
  sudo kubectl apply -f ~/$REMOTE_DIR/phpmyadmin.yaml
  echo 'Waiting for PhpMyAdmin to be ready...'
  sudo kubectl -n wordpress wait --for=condition=ready pod -l app=phpmyadmin --timeout=180s || true
"


# STEP 6: Verify WordPress is working (without TLS)
echo "===== STEP 6: VERIFYING WORDPRESS (WITHOUT TLS) ====="
echo "Checking WordPress HTTP access..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'Testing WordPress with curl...'
  
  # Try multiple methods to verify WordPress is accessible
  echo '1. Testing via service LoadBalancer:'
  NODE_PORT=\$(sudo kubectl get svc wordpress-lb -n wordpress -o jsonpath='{.spec.ports[0].nodePort}')
  HTTP_STATUS=\$(curl -s -o /dev/null -w '%{http_code}' http://localhost:\$NODE_PORT)
  echo \"HTTP Status: \$HTTP_STATUS\"
  
  echo '2. Testing via Ingress:'
  INGRESS_STATUS=\$(curl -s -o /dev/null -w '%{http_code}' -H \"Host: $MASTER_IP.nip.io\" http://localhost)
  echo \"Ingress Status: \$INGRESS_STATUS\"
  
  if [[ \$HTTP_STATUS == '200' || \$INGRESS_STATUS == '200' ]]; then
    echo 'WordPress is working correctly over HTTP!'
  else
    echo 'Warning: WordPress may not be fully accessible. Continuing anyway...'
  fi
"
# STEP 7: Install cert-manager
echo "===== STEP 7: INSTALLING CERT-MANAGER ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  # Apply cert-manager
  echo 'Applying cert-manager CRDs and controllers...'
  sudo kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
  
  # Wait for cert-manager pods to be ready
  echo 'Waiting for cert-manager to be ready...'
  for i in \$(seq 1 10); do
    if sudo kubectl -n cert-manager wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager --timeout=30s; then
      echo 'Cert-manager is ready!'
      break
    fi
    
    if [ \$i -eq 10 ]; then
      echo 'Timed out waiting for cert-manager to be ready.'
      exit 1
    fi
    
    echo 'Still waiting for cert-manager... (\$i/10)'
    sleep 15
  done
"
# STEP 8: Configure ACME challenge handling
echo "===== STEP 8: CONFIGURING ACME CHALLENGE HANDLING ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  # Create a dedicated ingress for ACME challenges
  cat > ~/acme-solver-ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: acme-challenge-ingress
  namespace: wordpress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: \"false\"
    nginx.ingress.kubernetes.io/use-regex: \"true\"
spec:
  rules:
  - host: $MASTER_IP.nip.io
    http:
      paths:
      - path: /.well-known/acme-challenge/(.*)
        pathType: Prefix
        backend:
          service:
            name: cm-acme-http-solver
            port:
              number: 8089
EOF
  sudo kubectl apply -f ~/acme-solver-ingress.yaml || true
"
# STEP 9: Create ClusterIssuer for Let's Encrypt
echo "===== STEP 9: CONFIGURING LET'S ENCRYPT ISSUERS ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  # Create staging issuer first (for testing)
  cat > ~/letsencrypt-staging.yaml << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

  sudo kubectl apply -f ~/letsencrypt-staging.yaml
  
  # Wait a moment for the resources to be fully processed
  sleep 5
  
  # Apply production issuer
  sudo kubectl apply -f ~/$REMOTE_DIR/cert-manager/letsencrypt-issuer.yaml
  
  # Verify issuers
  echo 'Checking ClusterIssuers:'
  sudo kubectl get clusterissuers
"

# STEP 10: Update WordPress Ingress with TLS
echo "===== STEP 10: ENABLING TLS FOR WORDPRESS ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  # First test with staging issuer
  echo 'Updating ingress to use TLS with staging issuer...'
  sudo kubectl annotate ingress wordpress-ingress -n wordpress cert-manager.io/cluster-issuer=letsencrypt-staging --overwrite
  sudo kubectl annotate ingress wordpress-ingress -n wordpress nginx.ingress.kubernetes.io/ssl-redirect=true --overwrite
  
  # Add TLS spec to existing ingress
  sudo kubectl patch ingress wordpress-ingress -n wordpress --type=json -p='[{\"op\": \"add\", \"path\": \"/spec/tls\", \"value\": [{\"hosts\": [\"$MASTER_IP.nip.io\"], \"secretName\": \"wordpress-tls-staging\"}]}]'
  
  # Wait for certificate to be issued (staging)
  echo 'Waiting for staging certificate to be issued...'
  for i in \$(seq 1 15); do
    if sudo kubectl get certificate wordpress-tls-staging -n wordpress 2>/dev/null | grep True; then
      echo 'Staging certificate issued successfully!'
      break
    fi
    
    if [ \$i -eq 15 ]; then
      echo 'Timed out waiting for staging certificate.'
    fi
    
    echo 'Still waiting for certificate... (\$i/15)'
    sudo kubectl get challenges,orders,certificates -n wordpress
    sleep 20
  done
  
  # Switch to production issuer
  echo 'Switching to production issuer...'
  sudo kubectl annotate ingress wordpress-ingress -n wordpress cert-manager.io/cluster-issuer=letsencrypt-prod --overwrite
  
  # Update TLS secret name for production
  sudo kubectl patch ingress wordpress-ingress -n wordpress --type=json -p='[{\"op\": \"replace\", \"path\": \"/spec/tls/0/secretName\", \"value\": \"wordpress-tls\"}]'
  
  # Wait for certificate to be issued (production)
  echo 'Waiting for production certificate to be issued...'
  for i in \$(seq 1 15); do
    if sudo kubectl get certificate wordpress-tls -n wordpress 2>/dev/null | grep True; then
      echo 'Production certificate issued successfully!'
      break
    fi
    
    if [ \$i -eq 15 ]; then
      echo 'Timed out waiting for production certificate.'
    fi
    
    echo 'Still waiting for certificate... (\$i/15)'
    sudo kubectl get challenges,orders,certificates -n wordpress
    sleep 20
  done
"

# STEP 11: Verify WordPress with TLS and detect NodePorts
echo "===== STEP 11: VERIFYING WORDPRESS WITH TLS ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'Checking WordPress status:'
  sudo kubectl get all -n wordpress
  
  echo 'Checking certificate status:'
  sudo kubectl get certificate -n wordpress
  
  echo 'Checking ingress status:'
  sudo kubectl get ingress -n wordpress
  
  echo 'Detecting NodePorts for access...'
  HTTP_PORT=\$(sudo kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.name==\"http\")].nodePort}')
  HTTPS_PORT=\$(sudo kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.name==\"https\")].nodePort}')
  echo \"HTTP NodePort: \$HTTP_PORT\"
  echo \"HTTPS NodePort: \$HTTPS_PORT\"
  
  echo 'Testing HTTPS access...'
  HTTPS_STATUS=\$(curl -k -s -o /dev/null -w '%{http_code}' https://$MASTER_IP.nip.io:\$HTTPS_PORT)
  echo \"HTTPS Status: \$HTTPS_STATUS\"
  
  if [[ \$HTTPS_STATUS == '200' ]]; then
    echo 'SUCCESS: WordPress is working correctly over HTTPS!'
  else
    echo 'Warning: WordPress may not be fully accessible over HTTPS.'
  fi
"

# STEP 12: Create monitoring and backup scripts
echo "===== STEP 12: SETTING UP MONITORING AND BACKUP ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  # Create monitoring script
  cat > ~/monitor-wordpress.sh << 'EOF'
#!/bin/bash
echo '===== WORDPRESS HEALTH CHECK ====='
echo 'Checking pods:'
sudo kubectl get pods -n wordpress

echo 'Checking services:'
sudo kubectl get svc -n wordpress

echo 'Checking persistent volumes:'
sudo kubectl get pv,pvc -n wordpress

echo 'Checking ingress:'
sudo kubectl get ingress -n wordpress

echo 'Checking certificates:'
sudo kubectl get certificate -n wordpress

echo 'Checking WordPress logs:'
WP_POD=$(sudo kubectl get pods -n wordpress -l app=wordpress -o jsonpath='{.items[0].metadata.name}')
sudo kubectl logs -n wordpress $WP_POD --tail=20

echo 'Checking MySQL logs:'
MYSQL_POD=$(sudo kubectl get pods -n wordpress -l tier=mysql -o jsonpath='{.items[0].metadata.name}')
sudo kubectl logs -n wordpress $MYSQL_POD --tail=20

echo 'Checking ingress controller logs:'
NGINX_POD=$(sudo kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
sudo kubectl logs -n ingress-nginx $NGINX_POD --tail=20
EOF
  chmod +x ~/monitor-wordpress.sh
  
  # Create backup script
  cat > ~/backup-wordpress.sh << 'EOF'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR=~/wordpress-backups/$TIMESTAMP
mkdir -p $BACKUP_DIR

# Backup WordPress resources
echo 'Backing up WordPress resources...'
sudo kubectl get all -n wordpress -o yaml > $BACKUP_DIR/wordpress-all.yaml
sudo kubectl get pvc -n wordpress -o yaml > $BACKUP_DIR/wordpress-pvc.yaml
sudo kubectl get configmap -n wordpress -o yaml > $BACKUP_DIR/wordpress-configmaps.yaml
sudo kubectl get secret -n wordpress -o yaml > $BACKUP_DIR/wordpress-secrets.yaml
sudo kubectl get ingress -n wordpress -o yaml > $BACKUP_DIR/wordpress-ingress.yaml

# Backup MySQL database
echo 'Backing up MySQL database...'
MYSQL_POD=$(sudo kubectl get pods -n wordpress -l tier=mysql -o jsonpath='{.items[0].metadata.name}')
PASSWORD=$(sudo kubectl get secret mysql-pass -n wordpress -o jsonpath='{.data.password}' | base64 --decode)
sudo kubectl exec -n wordpress $MYSQL_POD -- mysqldump -u wordpress -p$PASSWORD wordpress > $BACKUP_DIR/wordpress-db.sql

echo "Backup completed: $BACKUP_DIR"
EOF
  chmod +x ~/backup-wordpress.sh
  
  echo 'Monitoring and backup scripts created:'
  echo '- ~/monitor-wordpress.sh'
  echo '- ~/backup-wordpress.sh'
"

echo "===== DEPLOYMENT COMPLETE ====="
echo "Your WordPress site should now be accessible at:"
echo "- HTTP: http://$MASTER_IP.nip.io"
echo "- HTTPS: https://$MASTER_IP.nip.io (check the NodePort from the output above)"
echo ""
echo "To troubleshoot, SSH to the server and run:"
echo "- Check status: ~/monitor-wordpress.sh"
echo "- Create backup: ~/backup-wordpress.sh"

