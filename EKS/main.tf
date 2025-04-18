# Reference the VPC + subnets created by the Jenkins Terraform
#data "terraform_remote_state" "jenkins_vpc" {
#  backend = "s3"
#  config = {
#    bucket = "private-ai-iac-bucket"
#    key    = "jenkins/terraform.tfstate"
#    region = "us-east-1"
#  }
#}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version = "20.35.0"
  cluster_name    = "my-eks-cluster"
  cluster_version = "1.27"

  enable_irsa = true

  cluster_endpoint_public_access = true

  # Reference VPC and Subnets from remote Jenkins stack
  #vpc_id     = data.terraform_remote_state.jenkins_vpc.outputs.vpc_id
  #subnet_ids = data.terraform_remote_state.jenkins_vpc.outputs.private_subnet_ids
  
  # Directly specify the VPC and Subnet IDs instead of referencing remote state
  vpc_id     = "vpc-0b1dd112d58d0addf"  # Replace with your VPC ID
  subnet_ids = [
    "subnet-03cc14906803c221e"  # Replace with your subnet IDs (e.g., private subnets)
  ]

  # Use access_entries for access management
  access_entries = {
    jenkins_access = {
      principal_arn = "arn:aws:iam::891612581521:role/jenkins-eks-iam-auth-role"
      policy_associations = {
        jenkins_policy = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type       = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    frontend = {
      instance_type = ["t3.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 3
      labels = {
        app = "frontend"
      }
    }

    backend = {
      instance_type = ["t3.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 3
      labels = {
        app = "backend"
      }
    }

    redis = {
      instance_type = ["t3.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 3
      labels = {
        app = "redis"
      }
    }

    weaviate = {
      instance_types = ["m5.large"] # More memory/CPU for DB
      desired_size   = 1
      min_size       = 1
      max_size       = 3
      labels = {
        app = "weaviate"
      }
    }

    ollama = {
      instance_types = ["g4dn.xlarge"] # GPU support
      desired_size   = 3
      min_size       = 1
      max_size       = 5
      labels = {
        app = "ollama"
        gpu = "true"
      }
      taints = [{
        key    = "gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
    Project     = "MyApp"
  }
}
