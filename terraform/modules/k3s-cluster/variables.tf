variable "project_name" {
  description = "Project name used for tagging resources"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the instances"
  type        = list(string)
}

variable "node_count" {
  description = "Number of nodes in the cluster"
  type        = number
  default     = 2
}

# variable "ssh_key_path" {
#   description = "Path to SSH key for connecting to instances"
#   type        = string
#   default     = "ds_exam_key.pem"
# }
