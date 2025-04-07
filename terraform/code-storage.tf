# S3 bucket for code storage and state backups
resource "aws_s3_bucket" "code_storage" {
  bucket = "ds-exam-code-storage-${random_string.bucket_suffix.result}"
  
  tags = {
    Name        = "${var.project_name}-code-storage"
    Environment = var.environment
  }
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

# Lifecycle rules for code storage
resource "aws_s3_bucket_lifecycle_configuration" "state_backup_lifecycle" {
  bucket = aws_s3_bucket.code_storage.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"
    
    # Add filter block (required in newer AWS provider versions)
    filter {
      prefix = ""  # Empty prefix means apply to all objects
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "delete-old-versions"
    status = "Enabled"
    
    # Add filter block
    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}




# Output the bucket name
output "code_storage_bucket_name" {
  value = aws_s3_bucket.code_storage.bucket
}
