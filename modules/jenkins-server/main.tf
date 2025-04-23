terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket = "private-ai-iac-bucket"
    key    = "jenkins-server/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Reference network outputs using terraform_remote_state
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "private-ai-iac-bucket"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

# EC2

resource "aws_instance" "jenkins-ec2-server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
  vpc_security_group_ids      = [data.terraform_remote_state.network.outputs.jenkins_sg_id]
  key_name                    = var.key_pair_name
  monitoring                  = true
  user_data                   = file("${path.module}/jenkins-install.sh")
  associate_public_ip_address = true


  root_block_device {
    volume_size = var.root_volume_size
  }

  tags = {
    Name        = "Jenkins-Server"
    Terraform   = "true"
    Environment = "dev"
  }
}

