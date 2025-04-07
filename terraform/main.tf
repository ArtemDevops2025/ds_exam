provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  aws_region           = var.aws_region
}

module "k3s_cluster" {
  source = "./modules/k3s-cluster"

  project_name  = "ds-exam"  
  environment   = "dev"      
  region        = "eu-west-3" 
  instance_type = "t3.medium"
  key_name      = "ds_exam_key"  
  vpc_id        = module.vpc.vpc_id  
  subnet_ids    = module.vpc.public_subnet_ids  
  node_count    = 3  # 1 master + 2 worker
  create_elastic_ips = var.create_elastic_ips
}


/*
module "ec2" {
  source = "./modules/ec2"

  project_name       = var.project_name
  environment        = var.environment
  instance_type      = var.instance_type
  key_name           = var.key_name
  instance_count     = var.instance_count
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
}
*/