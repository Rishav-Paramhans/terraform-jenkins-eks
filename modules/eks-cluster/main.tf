terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket = "private-ai-iac-bucket"
    key    = "eks-cluster/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Reference network outputs using terraform_remote_state
data "terraform_remote_state" "network" {
  backend = "remote"
  config = {
    organization = "VJ_Terraform"
    workspaces = {
      name = "network_workspace" # Name of the network workspace in TFC
    }
  }
}
# --- Create Security Group for EKS Nodes ---
resource "aws_security_group" "eks_nodes" {
  name        = "eks_nodes_sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = "vpc-01ca446be893bad0e"

  tags = {
    Name        = "eks_nodes_sg"
    Environment = "dev"
  }
}

# --- Allow Jenkins EC2 to Access EKS Nodes on HTTPS (443) ---
resource "aws_security_group_rule" "jenkins_to_eks_nodes_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = "sg-076b09078b9d3d760" # Jenkins EC2 SG
  description              = "Allow Jenkins EC2 to access EKS nodes over HTTPS"
}
resource "aws_security_group_rule" "jenkins_to_eks_nodes_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = "sg-076b09078b9d3d760" # Jenkins EC2's SG
  description              = "Allow Jenkins EC2 to SSH into EKS nodes"
}


module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.36.0"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                                   = "vpc-01ca446be893bad0e"
  subnet_ids                               = ["subnet-0ffd0950ec3de3b50", "subnet-0932a11f28a59297c"]
  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true
  #manage_aws_auth_configmap = false
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = false

  eks_managed_node_group_defaults = {
    vpc_security_group_ids = [aws_security_group.eks_nodes.id]
  }

  eks_managed_node_groups = {
    frontend = {
      instance_types = ["t3.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 2
      labels = {
        app = "frontend"
      }
    }

    backend = {
      instance_types = ["t3.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 2
      labels = {
        app = "backend"
      }
    }

    redis = {
      instance_types = ["t3.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 2
      labels = {
        app = "redis"
      }
    }

    weaviate = {
      instance_types = ["m5.large"] # More memory/CPU for DB
      desired_size   = 1
      min_size       = 1
      max_size       = 2
      labels = {
        app = "weaviate"
      }
    }

    ollama = {
      ami_type       = "AL2_x86_64_GPU"             # ADD THIS LINE
      instance_types = ["g4dn.xlarge"] # GPU support
      desired_size   = 1
      min_size       = 1
      max_size       = 7
      key_name       = "jenkins-terraform-eks_KP"
      labels = {
        "nvidia.com/gpu.present" = "true"  # More specific label
      }
      taints = []   # Remove taints if using GPU Operator's automated scheduling
      
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
    Project     = "MyApp"
  }
}

