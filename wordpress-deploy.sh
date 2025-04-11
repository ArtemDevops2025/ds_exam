#!/bin/bash
# Verify WordPress deployment and monitoring stack are working correctly

# Set variables with absolute paths
MASTER_IP=$(cd /home/a/IT/GroupExam/ds_exam_group/terraform && terraform output -raw k3s_master_ip)
SSH_KEY="ds_exam_key.pem"
TERRAFORM_DIR="/home/a/IT/GroupExam/ds_exam_group/terraform"

echo "=== VERIFICATION REPORT ==="
echo "Master IP: $MASTER_IP"
echo

# 1. Verify Elastic IPs are correctly assigned
echo "=== ELASTIC IP VERIFICATION ==="
cd $TERRAFORM_DIR && terraform output -raw k3s_master_ip
echo

# 2. Verify Kubernetes components
echo "=== KUBERNETES COMPONENTS VERIFICATION ==="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get nodes -o wide"
echo

# 3. Verify WordPress namespace and resources
echo "=== WORDPRESS DEPLOYMENT VERIFICATION ==="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get all -n wordpress"
echo

# 4. Verify Ingress controller
echo "=== INGRESS CONTROLLER VERIFICATION ==="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get pods -n ingress-nginx"
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get svc -n ingress-nginx"
echo

# 5. Verify WordPress Ingress with detailed output
echo "=== WORDPRESS INGRESS VERIFICATION ==="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get ingress -n wordpress -o wide"
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl describe ingress wordpress-ingress -n wordpress | grep -A5 'Rules:'"
echo

# 6. Test WordPress HTTP access
echo "=== WORDPRESS HTTP ACCESS VERIFICATION ==="
echo "Testing Load Balancer access..."

# Get the NodePort for the wordpress-lb service
NODEPORT=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get svc wordpress-lb -n wordpress -o jsonpath='{.spec.ports[0].nodePort}'")
echo "WordPress NodePort: $NODEPORT"

# Test the Load Balancer access using the correct NodePort
LB_STATUS=$(curl -L -s -o /dev/null -w "%{http_code}" http://$MASTER_IP:$NODEPORT)
echo "HTTP Status: $LB_STATUS"
if [[ $LB_STATUS == "200" || $LB_STATUS == "301" || $LB_STATUS == "302" ]]; then
  echo "✅ Load Balancer access working"
else
  echo "❌ Load Balancer access failed"
fi

echo "Testing Ingress access..."
# Test ingress by directly accessing the ingress controller with Host header
INGRESS_STATUS=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "curl -L -s -o /dev/null -w \"%{http_code}\" -H \"Host: $MASTER_IP.nip.io\" http://localhost")
echo "HTTP Status: $INGRESS_STATUS"
if [[ $INGRESS_STATUS == "200" || $INGRESS_STATUS == "301" || $INGRESS_STATUS == "302" ]]; then
  echo "✅ Ingress access working"
else
  echo "❌ Ingress access failed"
fi
echo

# 7. Verify WordPress is responding with content
echo "=== WORDPRESS CONTENT VERIFICATION ==="
echo "Checking WordPress homepage..."
# Use SSH to run curl on the server itself to avoid DNS issues
HOMEPAGE=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "curl -L -s -H \"Host: $MASTER_IP.nip.io\" http://localhost")
if [[ $HOMEPAGE == *"WordPress"* ]]; then
  echo "✅ WordPress content detected"
else
  echo "❌ WordPress content not detected"
fi

echo "Checking WordPress admin page..."
ADMIN_STATUS=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "curl -L -s -o /dev/null -w \"%{http_code}\" -H \"Host: $MASTER_IP.nip.io\" http://localhost/wp-admin/")
if [[ $ADMIN_STATUS == "200" || $ADMIN_STATUS == "301" || $ADMIN_STATUS == "302" ]]; then
  echo "✅ WordPress admin page accessible (Status: $ADMIN_STATUS)"
else
  echo "❌ WordPress admin page not accessible (Status: $ADMIN_STATUS)"
fi
echo

# 8. Verify Monitoring namespace and resources
echo "=== MONITORING STACK VERIFICATION ==="
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get all -n monitoring"
echo

# 9. Verify Prometheus deployment
echo "=== PROMETHEUS VERIFICATION ==="
# Check if Prometheus pods are running
PROMETHEUS_PODS=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get pods -n monitoring -l app=prometheus -o jsonpath='{.items[*].status.phase}'")
if [[ $PROMETHEUS_PODS == "Running" ]]; then
  echo "✅ Prometheus pods are running"
else
  echo "❌ Prometheus pods are not running"
fi

# Test Prometheus HTTP access
PROMETHEUS_PORT="30909"
PROMETHEUS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$MASTER_IP:$PROMETHEUS_PORT)
echo "Prometheus HTTP Status: $PROMETHEUS_STATUS"
if [[ $PROMETHEUS_STATUS == "200" ]]; then
  echo "✅ Prometheus UI is accessible"
else
  echo "❌ Prometheus UI is not accessible"
fi

# Check if Prometheus can scrape targets
PROMETHEUS_TARGETS=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "curl -s http://localhost:$PROMETHEUS_PORT/api/v1/targets | grep -c \"up\"")
if [[ $PROMETHEUS_TARGETS -gt 0 ]]; then
  echo "✅ Prometheus is scraping targets"
else
  echo "❌ Prometheus is not scraping targets"
fi
echo

# 10. Verify Grafana deployment
echo "=== GRAFANA VERIFICATION ==="
# Check if Grafana pods are running
GRAFANA_PODS=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get pods -n monitoring -l app=grafana -o jsonpath='{.items[*].status.phase}'")
if [[ $GRAFANA_PODS == "Running" ]]; then
  echo "✅ Grafana pods are running"
else
  echo "❌ Grafana pods are not running"
fi

# Test Grafana HTTP access
GRAFANA_PORT="30300"
GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$MASTER_IP:$GRAFANA_PORT)
echo "Grafana HTTP Status: $GRAFANA_STATUS"
if [[ $GRAFANA_STATUS == "200" || $GRAFANA_STATUS == "302" ]]; then
  echo "✅ Grafana UI is accessible"
else
  echo "❌ Grafana UI is not accessible"
fi

# Check if Grafana login works (basic check)
GRAFANA_LOGIN=$(ssh -i $SSH_KEY ubuntu@$MASTER_IP "curl -s -o /dev/null -w \"%{http_code}\" -X POST -H \"Content-Type: application/json\" -d '{\"user\":\"admin\",\"password\":\"admin123\"}' http://localhost:$GRAFANA_PORT/login")
if [[ $GRAFANA_LOGIN == "200" || $GRAFANA_LOGIN == "302" ]]; then
  echo "✅ Grafana login is working"
else
  echo "❌ Grafana login is not working"
fi
echo

echo "=== VERIFICATION COMPLETE ==="
echo "If all tests passed, your WordPress deployment and monitoring stack are working correctly!"
echo "Access your WordPress site at:"
echo "- Load Balancer: http://$MASTER_IP:$NODEPORT"
echo "- Ingress: http://$MASTER_IP.nip.io"
echo "Access monitoring tools at:"
echo "- Prometheus: http://$MASTER_IP:30909"
echo "- Grafana: http://$MASTER_IP:30300 (login with admin/admin123)"
