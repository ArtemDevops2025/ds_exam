terraform {
  # Use local backend initially
  backend "local" {}

/* Ask, if we need it for terraform stete only!!!!!
  backend "s3" {
    bucket         = "ds-exam-terraform-state"  
    key            = "terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "ds-exam-terraform-locks"  
  }
  */
}
