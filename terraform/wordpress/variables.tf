variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  default     = "~/.kube/config"
}

variable "mysql_password" {
  description = "MySQL root password"
  sensitive   = true
}

variable "s3_bucket" {
  description = "S3 bucket name"
  default     = "ds-exam-app-data-xotjx8lp"  #previos created bucket
  }

variable "s3_region" {
  description = "S3 bucket region"
  default     = "eu-west-3"
}
variable "aws_access_key" {
  description = "AWS Access Key for S3 access"
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key for S3 access"
  sensitive   = true
}
