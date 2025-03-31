terraform {
  # Use local backend initially
  backend "local" {}

/*
  backend "s3" {
    bucket         = "ds-exam-terraform-state"  # Create this bucket manually
    key            = "terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "ds-exam-terraform-locks"  # Create this table manually
  }
  */
}
