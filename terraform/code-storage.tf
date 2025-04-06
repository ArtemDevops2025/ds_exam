# S3 bucket for code storage
resource "aws_s3_bucket" "code_storage" {
  bucket = "ds-exam-code-storage-${random_string.bucket_suffix.result}"
  
  tags = {
    Name        = "DS Exam Code Storage"
    Environment = "Exam"
    Purpose     = "Code Storage"
  }
}

# Enable versioning for the bucket
resource "aws_s3_bucket_versioning" "code_versioning" {
  bucket = aws_s3_bucket.code_storage.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "code_encryption" {
  bucket = aws_s3_bucket.code_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "code_public_access" {
  bucket = aws_s3_bucket.code_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Output the bucket name
output "code_storage_bucket_name" {
  value = aws_s3_bucket.code_storage.bucket
  description = "Name of the S3 bucket for code storage"
}

# Output the bucket ARN
output "code_storage_bucket_arn" {
  value = aws_s3_bucket.code_storage.arn
  description = "ARN of the S3 bucket for code storage"
}

#For terraform backup

# Lifecycle policy for terraform state backups
resource "aws_s3_bucket_lifecycle_configuration" "state_backup_lifecycle" {
  bucket = aws_s3_bucket.code_storage.id

  rule {
    id = "terraform-state-backups"
    status = "Enabled"
    
    filter {
      prefix = "terraform-state-backups/"
    }

    # Keep the last 30 days of backups
    expiration {
      days = 30
    }
    
    # Move older backups to cheaper storage
    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }
  }
}
