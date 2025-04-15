provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Generate random suffix for globally unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  # Common naming convention for resources
  name_suffix = random_string.suffix.result
  
  # Common tags for all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  aws_region           = var.aws_region
  common_tags          = local.common_tags
}

module "k3s_cluster" {
  source = "./modules/k3s-cluster"

  project_name  = var.project_name
  environment   = var.environment
  region        = var.aws_region
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_id        = module.vpc.vpc_id  
  subnet_ids    = module.vpc.public_subnet_ids  
  node_count    = var.instance_count
  create_elastic_ips = var.create_elastic_ips
  common_tags   = local.common_tags
}
# Environment-specific S3 bucket for application data
resource "aws_s3_bucket" "app_data" {
  bucket = "ds-${var.project_name}-${var.environment}-app-data-${local.name_suffix}"
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-data"
  })
}
resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for app data bucket
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket for code storage and state backups - with environment in name
resource "aws_s3_bucket" "code_storage" {
  bucket = "ds-${var.project_name}-${var.environment}-code-storage-${local.name_suffix}"
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-code-storage"
  })
}

resource "aws_s3_bucket_public_access_block" "code_storage" {
  bucket = aws_s3_bucket.code_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for code storage
resource "aws_s3_bucket_versioning" "code_storage" {
  bucket = aws_s3_bucket.code_storage.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "code_storage" {
  bucket = aws_s3_bucket.code_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

