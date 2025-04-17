# S3 bucket for application data
resource "aws_s3_bucket" "app_data" {
  bucket = "ds-exam-app-data-${random_string.bucket_suffix.result}"
  
  tags = {
    Name        = "${var.project_name}-app-data"
    Environment = var.environment
  }
}


resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}


resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  
  versioning_configuration {
    status = "Enabled"
  }
}