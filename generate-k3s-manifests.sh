#!/bin/bash
# generate-k8s-manifests.sh - Generate environment-specific Kubernetes manifests

# Usage: ./generate-k8s-manifests.sh dev|prod

if [ $# -ne 1 ]; then
  echo "Usage: $0 <environment>"
  echo "Where <environment> is dev or prod"
  exit 1
fi

ENV=$1
TEMPLATE_DIR="kubernetes/templates"
OUTPUT_DIR="kubernetes/environments/$ENV"
TERRAFORM_DIR="terraform"

# Create output directory
mkdir -p $OUTPUT_DIR

# Export TF_VAR variables based on environment
if [ "$ENV" = "dev" ]; then
  export TF_VAR_file="environments/dev/terraform.tfvars"
else
  export TF_VAR_file="environments/prod/terraform.tfvars"
fi

# Read terraform outputs with the correct environment
cd $TERRAFORM_DIR
terraform init
terraform workspace select $ENV 2>/dev/null || terraform workspace new $ENV
terraform apply -var-file=$TF_VAR_file -auto-approve

S3_BUCKET=$(terraform output -raw s3_bucket_name)
MASTER_IP=$(terraform output -raw k3s_master_ip)
S3_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "eu-west-3")
cd ..

# Set environment-specific values
if [ "$ENV" = "dev" ]; then
  REPLICA_COUNT=1
  MEMORY_REQUEST="256Mi"
  MEMORY_LIMIT="512Mi"
  CPU_REQUEST="200m"
  CPU_LIMIT="500m"
  CERT_ISSUER="staging"  # Use staging issuer for dev to avoid rate limits
else  # prod
  REPLICA_COUNT=2
  MEMORY_REQUEST="512Mi"
  MEMORY_LIMIT="1Gi"
  CPU_REQUEST="500m"
  CPU_LIMIT="1000m"
  CERT_ISSUER="prod"
fi

# Set hostname 
HOSTNAME="${MASTER_IP}.nip.io"

# Process each template file
for template in $TEMPLATE_DIR/*.yaml.tpl; do
  filename=$(basename $template .tpl)
  output_file="$OUTPUT_DIR/$filename"
  
  # Replace variables in template
  sed \
    -e "s/\${environment}/$ENV/g" \
    -e "s/\${s3_bucket}/$S3_BUCKET/g" \
    -e "s/\${s3_region}/$S3_REGION/g" \
    -e "s/\${replica_count}/$REPLICA_COUNT/g" \
    -e "s/\${hostname}/$HOSTNAME/g" \
    -e "s/\${memory_request}/$MEMORY_REQUEST/g" \
    -e "s/\${memory_limit}/$MEMORY_LIMIT/g" \
    -e "s/\${cpu_request}/$CPU_REQUEST/g" \
    -e "s/\${cpu_limit}/$CPU_LIMIT/g" \
    -e "s/\${cert_issuer}/$CERT_ISSUER/g" \
    $template > $output_file
  
  echo "Generated $output_file"
done

# Copy fixed manifests
cp kubernetes/*.yaml $OUTPUT_DIR/ 2>/dev/null || true

echo "Environment-specific Kubernetes manifests generated for $ENV environment"