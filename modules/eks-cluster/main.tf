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

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "21.0.0"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                                   = "vpc-01ca446be893bad0e"
  subnet_ids                               = ["subnet-0ffd0950ec3de3b50", "subnet-0932a11f28a59297c"]
  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true
  manage_aws_auth_configmap = true
  cluster_endpoint_public_access = true

  # Use access_entries for access management

  access_entries = {
    jenkins_access = {
      principal_arn = "arn:aws:iam::891612581521:role/jenkins-eks_cluster_admin_access-role"
      policy_associations = {
        jenkins_policy = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    
    # Add the new vaibhav_access entry for the IAM user "vaibhav-user"
    vaibhav_access = {
      principal_arn = "arn:aws:iam::891612581521:user/vaibhav-user"
      policy_associations = {
        rishav_policy = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  
    rishav_access = {
        principal_arn = "arn:aws:iam::891612581521:user/rishav-user"
        policy_associations = {
          rishav_policy = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
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
      instance_types = ["g4dn.xlarge"] # GPU support
      desired_size   = 1
      min_size       = 1
      max_size       = 2
      labels = {
        app = "ollama"
        gpu = "true"
      }
      taints = [{
        key    = "gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
      # Add user_data to install NVIDIA drivers automatically
      user_data = <<-EOF
        #!/bin/bash
        # Install NVIDIA drivers and CUDA
        sudo amazon-linux-extras enable gpu
        sudo yum install -y nvidia-driver
        sudo yum install -y cuda
        sudo reboot
      EOF
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
    Project     = "MyApp"
  }
}

