# AWS Credentials - NEVER commit this file to version control
aws_access_key = "AKIAWFWTHYOYLUSSXH5P"
aws_secret_key = "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"

# Project Information
project_name = "DS_Exam"
environment  = "dev"

# Region
aws_region = "eu-west-3"  # Paris

# Network
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

# EC2
instance_type    = "t3.medium"  # 2 vCPU, 4 GiB memory - good for k3s
key_name         = "ds_exam_key"  # Create this key pair in AWS console
instance_count   = 3  # 1 master, 2 workers

#Elastic IP
create_elastic_ips = true