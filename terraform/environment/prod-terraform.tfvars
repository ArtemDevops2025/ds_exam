# Production environment variables
environment         = "prod"
project_name        = "ds-exam"
vpc_cidr            = "10.1.0.0/16"  
public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]
instance_type       = "t3.medium"
instance_count      = 3  # More nodes for production
aws_region          = "eu-west-3"