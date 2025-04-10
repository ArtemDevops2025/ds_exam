#!/bin/bash
# update-wordpress-url.sh - Fix WordPress URL redirection issue

# Set variables
MASTER_IP=$(cd /home/a/IT/GroupExam/ds_exam_group/terraform && terraform output -raw k3s_master_ip)
SSH_KEY="ds_exam_key.pem"
NEW_URL="http://$MASTER_IP.nip.io"

echo "Updating WordPress site URL to $NEW_URL..."

# Proof MySQL pod name
MYSQL_POD=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get pods -n wordpress | grep mysql | awk '{print \$1}'")
echo "Found MySQL pod: $MYSQL_POD"

# Connect to the MySQL pod and update the WordPress database
if [ -n "$MYSQL_POD" ]; then
  ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl exec -it -n wordpress $MYSQL_POD -- mysql -u root -ppassword wordpress -e \"UPDATE wp_options SET option_value='$NEW_URL' WHERE option_name='siteurl' OR option_name='home';\""
  echo "WordPress site URL updated successfully!"
else
  echo "Error: MySQL pod not found!"
  exit 1
fi

echo "Please clear your browser cache and test the site again."
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

