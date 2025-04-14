#!/bin/bash
# comprehensive-verify.sh - Complete verification of WordPress deployment with TLS

# Set variables with absolute paths
MASTER_IP=$(cd /home/a/IT/GroupExam/ds_exam_group/terraform && terraform output -raw k3s_master_ip)
SSH_KEY="ds_exam_key.pem"
TERRAFORM_DIR="/home/a/IT/GroupExam/ds_exam_group/terraform"

echo "===== COMPREHENSIVE DEPLOYMENT VERIFICATION ====="
echo "Master IP: $MASTER_IP"
echo "Date: $(date)"
echo

# 1. Verify Elastic IPs are correctly assigned
echo "===== STEP 1: ELASTIC IP VERIFICATION ====="
cd $TERRAFORM_DIR && terraform output -raw k3s_master_ip
echo

# 2. Verify Kubernetes components
echo "===== STEP 2: KUBERNETES COMPONENTS VERIFICATION ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'Node status:'
  sudo kubectl get nodes -o wide
  
  echo 'Kubernetes version:'
  sudo kubectl version --short
  
  echo 'Cluster info:'
  sudo kubectl cluster-info
"
echo
# 3. Verify WordPress namespace and resources
echo "===== STEP 3: WORDPRESS DEPLOYMENT VERIFICATION ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'Namespace status:'
  sudo kubectl get namespace wordpress
  
  echo 'All resources in wordpress namespace:'
  sudo kubectl get all -n wordpress
  
  echo 'Persistent Volume Claims:'
  sudo kubectl get pvc -n wordpress
  
  echo 'ConfigMaps:'
  sudo kubectl get configmap -n wordpress
  
  echo 'Secrets:'
  sudo kubectl get secrets -n wordpress
  
  echo 'WordPress pod details:'
  WP_POD=\$(sudo kubectl get pods -n wordpress -l app=wordpress -o jsonpath='{.items[0].metadata.name}')
  sudo kubectl describe pod \$WP_POD -n wordpress | grep -A5 'State:'
  
  echo 'MySQL pod details:'
  MYSQL_POD=\$(sudo kubectl get pods -n wordpress -l tier=mysql -o jsonpath='{.items[0].metadata.name}')
  sudo kubectl describe pod \$MYSQL_POD -n wordpress | grep -A5 'State:'
  
  echo 'WordPress service endpoints:'
  sudo kubectl get endpoints -n wordpress
  
  echo 'WordPress deployment status:'
  sudo kubectl rollout status deployment/wordpress -n wordpress
  
  echo 'MySQL deployment status:'
  sudo kubectl rollout status deployment/wordpress-mysql -n wordpress
"
echo
# 4. Verify Ingress controller and Ingress resources
echo "===== STEP 4: INGRESS VERIFICATION ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'Ingress controller pods:'
  sudo kubectl get pods -n ingress-nginx
  
  echo 'Ingress controller services:'
  sudo kubectl get svc -n ingress-nginx
  
  echo 'Ingress controller configuration:'
  sudo kubectl get configmap -n ingress-nginx
  
  echo 'Ingress resources in wordpress namespace:'
  sudo kubectl get ingress -n wordpress -o wide
  
  echo 'Detailed ingress configuration:'
  sudo kubectl describe ingress -n wordpress
  
  echo 'Ingress controller logs (last 10 lines):'
  NGINX_POD=\$(sudo kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
  sudo kubectl logs \$NGINX_POD -n ingress-nginx --tail=10
  
  echo 'NodePorts for ingress controller:'
  HTTP_PORT=\$(sudo kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.name==\"http\")].nodePort}')
  HTTPS_PORT=\$(sudo kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.name==\"https\")].nodePort}')
  echo \"HTTP NodePort: \$HTTP_PORT\"
  echo \"HTTPS NodePort: \$HTTPS_PORT\"
"
echo
# 5. Verify TLS certificates and HTTPS functionality
echo "===== STEP 5: TLS CERTIFICATE VERIFICATION ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'Cert-manager pods:'
  sudo kubectl get pods -n cert-manager
  
  echo 'ClusterIssuers:'
  sudo kubectl get clusterissuers
  
  echo 'Certificates in wordpress namespace:'
  sudo kubectl get certificate -n wordpress
  
  echo 'Certificate details:'
  sudo kubectl describe certificate -n wordpress
  
  echo 'Certificate secrets:'
  sudo kubectl get secret -n wordpress | grep tls
  
  echo 'ACME orders and challenges:'
  sudo kubectl get orders,challenges -n wordpress
  
  echo 'Testing HTTPS connectivity with curl:'
  curl -I -k https://$MASTER_IP.nip.io
  
  echo 'Verifying certificate with OpenSSL:'
  echo | openssl s_client -connect $MASTER_IP.nip.io:443 -servername $MASTER_IP.nip.io 2>/dev/null | grep -A10 'Certificate chain'
  echo | openssl s_client -connect $MASTER_IP.nip.io:443 -servername $MASTER_IP.nip.io 2>/dev/null | grep 'Verify return code'
"
echo
# 6. Comprehensive connectivity testing
echo "===== STEP 6: CONNECTIVITY TESTING ====="

# Get NodePorts for direct access
NODEPORT=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get svc wordpress-lb -n wordpress -o jsonpath='{.spec.ports[0].nodePort}'")
HTTPS_PORT=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.name==\"https\")].nodePort}'")

echo "WordPress NodePort: $NODEPORT"
echo "HTTPS NodePort: $HTTPS_PORT"

# Test direct NodePort access
echo "Testing direct NodePort access..."
LB_STATUS=$(curl -L -s -o /dev/null -w "%{http_code}" http://$MASTER_IP:$NODEPORT)
echo "HTTP Status (NodePort): $LB_STATUS"
if [[ $LB_STATUS == "200" || $LB_STATUS == "301" || $LB_STATUS == "302" ]]; then
  echo "✅ NodePort access working"
else
  echo "❌ NodePort access failed"
fi

# Test HTTP ingress access
echo "Testing HTTP ingress access..."
HTTP_STATUS=$(curl -L -s -o /dev/null -w "%{http_code}" -H "Host: $MASTER_IP.nip.io" http://$MASTER_IP)
echo "HTTP Status (Ingress): $HTTP_STATUS"
if [[ $HTTP_STATUS == "200" || $HTTP_STATUS == "301" || $HTTP_STATUS == "302" ]]; then
  echo "✅ HTTP ingress access working"
else
  echo "❌ HTTP ingress access failed"
fi

# Test HTTPS access
echo "Testing HTTPS access..."
HTTPS_STATUS=$(curl -L -k -s -o /dev/null -w "%{http_code}" https://$MASTER_IP.nip.io)
echo "HTTPS Status: $HTTPS_STATUS"
if [[ $HTTPS_STATUS == "200" || $HTTPS_STATUS == "301" || $HTTPS_STATUS == "302" ]]; then
  echo "✅ HTTPS access working"
else
  echo "❌ HTTPS access failed"
fi

# Test WordPress specific endpoints
echo "Testing WordPress specific endpoints..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'WordPress homepage:'
  HOMEPAGE=\$(curl -L -s -k -o /dev/null -w \"%{http_code}\" https://$MASTER_IP.nip.io/)
  echo \"Status: \$HOMEPAGE\"
  if [[ \$HOMEPAGE == \"200\" || \$HOMEPAGE == \"301\" || \$HOMEPAGE == \"302\" ]]; then
    echo \"✅ Homepage accessible\"
  else
    echo \"❌ Homepage not accessible\"
  fi
  
  echo 'WordPress admin page:'
  ADMIN=\$(curl -L -s -k -o /dev/null -w \"%{http_code}\" https://$MASTER_IP.nip.io/wp-admin/)
  echo \"Status: \$ADMIN\"
  if [[ \$ADMIN == \"200\" || \$ADMIN == \"301\" || \$ADMIN == \"302\" ]]; then
    echo \"✅ Admin page accessible\"
  else
    echo \"❌ Admin page not accessible\"
  fi
  
  echo 'WordPress login page:'
  LOGIN=\$(curl -L -s -k -o /dev/null -w \"%{http_code}\" https://$MASTER_IP.nip.io/wp-login.php)
  echo \"Status: \$LOGIN\"
  if [[ \$LOGIN == \"200\" || \$LOGIN == \"301\" || \$LOGIN == \"302\" ]]; then
    echo \"✅ Login page accessible\"
  else
    echo \"❌ Login page not accessible\"
  fi
  
  echo 'WordPress REST API:'
  API=\$(curl -L -s -k -o /dev/null -w \"%{http_code}\" https://$MASTER_IP.nip.io/wp-json/)
  echo \"Status: \$API\"
  if [[ \$API == \"200\" || \$API == \"301\" || \$API == \"302\" ]]; then
    echo \"✅ REST API accessible\"
  else
    echo \"❌ REST API not accessible\"
  fi
"
echo

# 7. PhpMyAdmin verification
echo "===== STEP 7: PHPMYADMIN VERIFICATION ====="

# Get PhpMyAdmin NodePort
PHPMYADMIN_PORT=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get svc phpmyadmin -n wordpress -o jsonpath='{.spec.ports[0].nodePort}'")
echo "PhpMyAdmin NodePort: $PHPMYADMIN_PORT"

# Test direct access to PhpMyAdmin via NodePort
echo "Testing PhpMyAdmin via NodePort..."
PHPMYADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$MASTER_IP:$PHPMYADMIN_PORT/)
echo "PhpMyAdmin HTTP Status (NodePort): $PHPMYADMIN_STATUS"
if [[ $PHPMYADMIN_STATUS == "200" || $PHPMYADMIN_STATUS == "302" ]]; then
  echo "✅ PhpMyAdmin accessible via NodePort"
else
  echo "❌ PhpMyAdmin not accessible via NodePort (Status: $PHPMYADMIN_STATUS)"
fi

# Run all remaining checks on the remote server
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  # Check for PhpMyAdmin content
echo "Checking PhpMyAdmin content..."
PHPMYADMIN_CONTENT=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "curl -s http://localhost:$PHPMYADMIN_PORT/ | grep -o 'phpMyAdmin' | head -1")
if [[ -n "$PHPMYADMIN_CONTENT" ]]; then
  echo "✅ PhpMyAdmin content detected: $PHPMYADMIN_CONTENT"
else
  echo "❌ PhpMyAdmin content not detected"
fi

  
  # Get PhpMyAdmin pod details
  echo 'PhpMyAdmin pod details:'
  PHPMYADMIN_POD=\$(sudo kubectl get pods -n wordpress -l app=phpmyadmin -o jsonpath='{.items[0].metadata.name}')
  sudo kubectl describe pod \$PHPMYADMIN_POD -n wordpress | grep -A5 'State:'
  
  # Get PhpMyAdmin pod logs
  echo 'PhpMyAdmin pod logs (last 5 lines):'
  sudo kubectl logs \$PHPMYADMIN_POD -n wordpress --tail=5
  
  # Test database connection
  echo 'Testing database connection from PhpMyAdmin:'
  MYSQL_POD=\$(sudo kubectl get pods -n wordpress -l tier=mysql -o jsonpath='{.items[0].metadata.name}')
  MYSQL_PASSWORD=\$(sudo kubectl get secret mysql-pass -n wordpress -o jsonpath='{.data.password}' | base64 --decode)
  
  # Test if PhpMyAdmin can connect to its own service
  if sudo kubectl exec \$PHPMYADMIN_POD -n wordpress -- curl -s --connect-timeout 5 http://localhost/ > /dev/null; then
    echo \"✅ PhpMyAdmin internal web service working\"
  else
    echo \"❌ PhpMyAdmin internal web service issue\"
  fi
  
  # Test if MySQL is accessible from PhpMyAdmin pod
  if sudo kubectl exec \$PHPMYADMIN_POD -n wordpress -- curl -s --connect-timeout 5 http://wordpress-mysql:3306 > /dev/null 2>&1; then
    echo \"✅ MySQL service is reachable from PhpMyAdmin pod\"
  else
    echo \"❌ MySQL service is not reachable from PhpMyAdmin pod (this is normal for TCP services)\"
  fi
  
  # Check if PhpMyAdmin is configured with the correct MySQL host
  CONFIG=\$(sudo kubectl exec \$PHPMYADMIN_POD -n wordpress -- grep -r 'PMA_HOST' /var/www/html/ 2>/dev/null || echo 'Not found')
  echo \"PhpMyAdmin MySQL configuration: \$CONFIG\"
"
echo


# 8. Security verification and final summary
echo "===== STEP 8: SECURITY VERIFICATION AND FINAL SUMMARY ====="

# Check security headers and TLS configuration
echo "Checking security headers and TLS configuration..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'Security headers check:'
  curl -s -I -k https://$MASTER_IP.nip.io | grep -E 'Strict-Transport-Security|X-Content-Type-Options|X-Frame-Options|Content-Security-Policy'
  
  echo 'TLS version and cipher check:'
  echo | openssl s_client -connect $MASTER_IP.nip.io:443 -servername $MASTER_IP.nip.io 2>/dev/null | grep -E 'Protocol|Cipher'
  
  echo 'Certificate expiration date:'
  echo | openssl s_client -connect $MASTER_IP.nip.io:443 -servername $MASTER_IP.nip.io 2>/dev/null | openssl x509 -noout -dates
  
  echo 'Checking for exposed sensitive endpoints:'
  PHPMYADMIN=\$(curl -s -k -o /dev/null -w \"%{http_code}\" https://$MASTER_IP.nip.io/phpmyadmin/)
  echo \"PhpMyAdmin status: \$PHPMYADMIN\"
  
  echo 'Checking ingress controller security settings:'
  sudo kubectl get configmap ingress-nginx-controller -n ingress-nginx -o yaml | grep -E 'ssl-protocols|ssl-ciphers|hsts'
"

# Generate final summary
echo "===== FINAL DEPLOYMENT SUMMARY ====="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  echo 'WordPress pods status:'
  sudo kubectl get pods -n wordpress -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready
  
  echo 'Certificate status:'
  sudo kubectl get certificate -n wordpress -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter
  
  echo 'Ingress status:'
  sudo kubectl get ingress -n wordpress -o custom-columns=NAME:.metadata.name,HOSTS:.spec.rules[0].host,TLS:.spec.tls[0].secretName
  
  echo 'Service endpoints:'
  sudo kubectl get endpoints -n wordpress
  
  echo 'Resource usage:'
  sudo kubectl top pods -n wordpress 2>/dev/null || echo 'Metrics server not available'
"

# Print access information
echo "===== ACCESS INFORMATION ====="
echo "Your WordPress site should be accessible at:"
echo "- HTTP: http://$MASTER_IP.nip.io (should redirect to HTTPS)"
echo "- HTTPS: https://$MASTER_IP.nip.io"
echo "- Direct NodePort: http://$MASTER_IP:$NODEPORT"
echo

echo "===== VERIFICATION COMPLETE ====="
echo "Timestamp: $(date)"
