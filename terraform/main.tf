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

