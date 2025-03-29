terraform {
  backend "s3" {
    bucket = "private-ai-iac-bucket"
    key    = "jenkins/terraform.tfstate"
    region = "us-east-1"
  }
}