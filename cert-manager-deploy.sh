#!/bin/bash
# cert-manager-deploy.sh - Robust version with aggressive cleanup

MASTER_IP=$(cd terraform && terraform output -raw k3s_master_ip)
SSH_KEY="ds_exam_key.pem"
LOCAL_YAML_DIR="/home/a/IT/GroupExam/ds_exam_group/kubernetes"
REMOTE_DIR="wordpress"
EMAIL="schmakov1@gmail.com"  # Replace with your actual email

echo "=== DEPLOYING CERT-MANAGER TO K3S CLUSTER ==="
echo "Master IP: $MASTER_IP"

# Create remote directory for cert-manager
ssh -i $SSH_KEY ubuntu@$MASTER_IP "mkdir -p ~/$REMOTE_DIR/cert-manager"

# Transfer cert-manager YAML files
echo "Transferring cert-manager manifests to master node..."
scp -i $SSH_KEY $LOCAL_YAML_DIR/cert-manager/*.yaml ubuntu@$MASTER_IP:~/$REMOTE_DIR/cert-manager/

# Update email in letsencrypt-issuer.yaml
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sed -i 's/your-email@example.com/$EMAIL/' ~/$REMOTE_DIR/cert-manager/letsencrypt-issuer.yaml"

# AGGRESSIVE CLEANUP SECTION
echo "Performing aggressive cleanup of stuck resources..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  # 1. Force remove finalizers from cert-manager resources
  echo 'Removing finalizers from cert-manager resources...'
  for resource in \$(sudo kubectl get challenges.acme.cert-manager.io,orders.acme.cert-manager.io,certificates.cert-manager.io,certificaterequests.cert-manager.io -n wordpress -o name 2>/dev/null); do
    echo \"Removing finalizers from \$resource\"
    sudo kubectl patch \$resource -n wordpress --type=json -p='[{\"op\":\"remove\",\"path\":\"/metadata/finalizers\"}]' 2>/dev/null || true
  done

  # 2. Force delete all cert-manager resources
  echo 'Force deleting cert-manager resources...'
  sudo kubectl delete challenges,orders,certificates,certificaterequests --all -n wordpress --force --grace-period=0 2>/dev/null || true
  
  # 3. Delete stuck svclb pods
  echo 'Deleting stuck service load balancer pods...'
  sudo kubectl delete pods -n kube-system -l svccontroller.k3s.cattle.io/svcname=phpmyadmin --force --grace-period=0 2>/dev/null || true
  
  # 4. Fix phpmyadmin service to avoid port conflicts
  echo 'Converting phpmyadmin service to ClusterIP...'
  sudo kubectl patch svc phpmyadmin -n wordpress -p '{\"spec\":{\"type\":\"ClusterIP\"}}' 2>/dev/null || true
  
  # 5. Force delete cert-manager namespace if it exists
  if sudo kubectl get namespace cert-manager &>/dev/null; then
    echo 'Force removing cert-manager namespace...'
    sudo kubectl delete namespace cert-manager --force --grace-period=0
    # Wait for namespace to be fully deleted
    for i in \$(seq 1 30); do
      if ! sudo kubectl get namespace cert-manager &>/dev/null; then
        break
      fi
      echo \"Waiting for cert-manager namespace to be deleted... (\$i/30)\"
      sleep 2
    done
  fi
"

# Apply cert-manager CRDs and manifests
echo "Applying cert-manager CRDs and manifests..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml"

# Wait for cert-manager pods to be ready
echo "Waiting for cert-manager pods to be ready..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "
  # Wait for deployments with timeout and retry
  for i in \$(seq 1 5); do
    echo \"Attempt \$i/5: Waiting for cert-manager deployments...\"
    if sudo kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=60s && \
       sudo kubectl wait --for=condition=available deployment/cert-manager-webhook -n cert-manager --timeout=60s && \
       sudo kubectl wait --for=condition=available deployment/cert-manager-cainjector -n cert-manager --timeout=60s; then
      echo \"All cert-manager deployments are ready!\"
      break
    fi
    echo \"Retrying in 10 seconds...\"
    sleep 10
  done
"

# Create proper RBAC permissions for cert-manager
echo "Creating proper RBAC permissions for cert-manager..."
cat <<EOF | ssh -i $SSH_KEY ubuntu@$MASTER_IP "cat > cert-manager-rbac.yaml && sudo kubectl apply -f cert-manager-rbac.yaml"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-manager-controller-issuers
rules:
- apiGroups: ["cert-manager.io"]
  resources: ["clusterissuers", "clusterissuers/status", "issuers", "issuers/status"]
  verbs: ["update", "patch", "get", "list", "watch", "create", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cert-manager-controller-issuers
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cert-manager-controller-issuers
subjects:
- kind: ServiceAccount
  name: cert-manager
  namespace: cert-manager
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-manager-controller-challenges
rules:
- apiGroups: ["acme.cert-manager.io"]
  resources: ["challenges", "orders", "challenges/status", "orders/status"]
  verbs: ["update", "patch", "get", "list", "watch", "create", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cert-manager-controller-challenges
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cert-manager-controller-challenges
subjects:
- kind: ServiceAccount
  name: cert-manager
  namespace: cert-manager
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cert-manager-wordpress
  namespace: wordpress
rules:
- apiGroups: ["cert-manager.io"]
  resources: ["certificates", "certificates/status", "certificaterequests", "certificaterequests/status"]
  verbs: ["get", "list", "watch", "update", "patch", "create", "delete"]
- apiGroups: [""]
  resources: ["secrets", "events", "configmaps", "services", "pods"]
  verbs: ["get", "list", "watch", "create", "update", "delete", "patch"]
- apiGroups: ["networking.k8s.io", "extensions"]
  resources: ["ingresses", "ingresses/status"]
  verbs: ["get", "list", "watch", "update", "create", "patch"]
- apiGroups: ["acme.cert-manager.io"]
  resources: ["challenges", "orders", "challenges/status", "orders/status"]
  verbs: ["get", "list", "watch", "create", "update", "delete", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cert-manager-wordpress
  namespace: wordpress
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cert-manager-wordpress
subjects:
- kind: ServiceAccount
  name: cert-manager
  namespace: cert-manager
EOF

# Ensure NGINX Ingress Controller exposes port 443 with correct configuration
echo "Configuring NGINX Ingress Controller for proper TLS and ACME challenge handling..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl patch svc ingress-nginx-controller -n ingress-nginx --type=merge -p '{\"spec\":{\"ports\":[{\"name\":\"http\",\"port\":80,\"protocol\":\"TCP\",\"targetPort\":80,\"nodePort\":30080},{\"name\":\"https\",\"port\":443,\"protocol\":\"TCP\",\"targetPort\":443,\"nodePort\":30103}]}}'"

# Create a ConfigMap to ensure proper ACME challenge handling
cat <<EOF | ssh -i $SSH_KEY ubuntu@$MASTER_IP "cat > ingress-nginx-config.yaml && sudo kubectl apply -f ingress-nginx-config.yaml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  allow-snippet-annotations: "true"
  proxy-body-size: "64m"
  proxy-read-timeout: "600"
  proxy-send-timeout: "600"
  ssl-protocols: "TLSv1.2 TLSv1.3"
  use-forwarded-headers: "true"
EOF

# Create staging issuer with improved HTTP-01 solver configuration
echo "Creating Let's Encrypt Staging ClusterIssuer with improved HTTP-01 configuration..."
cat <<EOF | ssh -i $SSH_KEY ubuntu@$MASTER_IP "cat > letsencrypt-staging.yaml && sudo kubectl apply -f letsencrypt-staging.yaml"
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
          podTemplate:
            spec:
              nodeSelector:
                kubernetes.io/os: linux
          ingressTemplate:
            metadata:
              annotations:
                nginx.ingress.kubernetes.io/whitelist-source-range: "0.0.0.0/0"
EOF

# Create production issuer
echo "Creating Let's Encrypt Production ClusterIssuer..."
cat <<EOF | ssh -i $SSH_KEY ubuntu@$MASTER_IP "cat > letsencrypt-prod.yaml && sudo kubectl apply -f letsencrypt-prod.yaml"
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                kubernetes.io/os: linux
          ingressTemplate:
            metadata:
              annotations:
                nginx.ingress.kubernetes.io/whitelist-source-range: "0.0.0.0/0"
EOF

# Restart ingress controller to pick up new configuration
echo "Restarting NGINX ingress controller..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx"
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl wait --for=condition=available deployment/ingress-nginx-controller -n ingress-nginx --timeout=60s"

# Update existing ingress to use TLS with staging issuer first
echo "Updating WordPress ingress to use TLS with staging issuer..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl annotate ingress wordpress-ingress -n wordpress cert-manager.io/cluster-issuer=letsencrypt-staging --overwrite"
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl annotate ingress wordpress-ingress -n wordpress nginx.ingress.kubernetes.io/ssl-redirect=true --overwrite"
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl patch ingress wordpress-ingress -n wordpress --type=json -p='[{\"op\": \"replace\", \"path\": \"/spec/tls\", \"value\": [{\"hosts\": [\"$MASTER_IP.nip.io\"], \"secretName\": \"wordpress-tls\"}]}]'"

# Restart cert-manager to pick up new permissions
echo "Restarting cert-manager to pick up new permissions..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl rollout restart deployment cert-manager -n cert-manager"

# Wait for cert-manager to be ready again
echo "Waiting for cert-manager to be ready again..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=60s"

# Verify certificate status
echo "Verifying certificate status (this may take a few minutes)..."
ssh -i $SSH_KEY ubuntu@$MASTER_IP "sudo kubectl get certificate -n wordpress"

echo "=== CERT-MANAGER DEPLOYMENT COMPLETE ==="
echo "Your WordPress site should now be accessible via HTTPS at:"
echo "https://$MASTER_IP.nip.io"
echo "Note: It may take 5-10 minutes for the certificate to be issued and become valid."
echo ""
echo "To check certificate status:"
echo "ssh -i $SSH_KEY ubuntu@$MASTER_IP \"sudo kubectl get certificate -n wordpress\""
echo ""
echo "To check ACME challenges:"
echo "ssh -i $SSH_KEY ubuntu@$MASTER_IP \"sudo kubectl get challenges,orders -n wordpress\""
echo ""
echo "Once the staging certificate is working, switch to production with:"
echo "ssh -i $SSH_KEY ubuntu@$MASTER_IP \"sudo kubectl annotate ingress wordpress-ingress -n wordpress cert-manager.io/cluster-issuer=letsencrypt-prod --overwrite\""
