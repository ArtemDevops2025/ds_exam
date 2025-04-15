terraform {
  # Use local backend initially
  backend "local" {
    # Will use terraform-{env}.tfstate based on workspace
  }

  /*
  # For S3 backend (can be implemented later)
  backend "s3" {
    bucket         = "ds-exam-terraform-state"  
    key            = "terraform.tfstate"  # Will be overridden in CI with environment-specific key
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "ds-exam-terraform-locks"  
  }
  */
}