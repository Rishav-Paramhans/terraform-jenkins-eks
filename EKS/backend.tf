terraform {
  backend "s3" {
    bucket = "private-ai-iac-bucket"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}