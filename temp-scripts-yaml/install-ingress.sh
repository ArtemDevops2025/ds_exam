#!/bin/bash
# Automate ingress-nginx controller installation !!!!! NEW
#chmod +x install-ingress.sh

set -e

echo "Installing ingress-nginx controller..."

# Create a temporary manifest file
cat > ingress-nginx-values.yaml << EOF
controller:
  service:
    externalIPs:
      - "13.37.209.198"  # Your master node Elastic IP
EOF

# Install Helm if not present
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash
fi

# Add the ingress-nginx repository
sudo helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
sudo helm repo update

# Install/upgrade the ingress-nginx controller
sudo helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f ingress-nginx-values.yaml

# Wait for the controller to be ready
echo "Waiting for ingress controller to be ready..."
sudo kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Verify the installation
echo "Ingress controller external IP:"
sudo kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip || .spec.externalIPs[0]}'
echo

echo "Ingress-Nginx controller installation complete!"
