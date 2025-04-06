module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "jenkins-vpc"
  cidr = var.vpc_cidr

  azs = data.aws_availability_zones.azs.names

  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/elb"               = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"      = 1
  }

}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "my-eks-cluster"
  cluster_version = "1.27"

  enable_irsa = true

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  manage_aws_auth_config = true

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::891612581521:role/jenkins-eks-iam-auth-role"
      username = "jenkins"
      groups   = ["system:masters"]
    }
  ]

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
      desired_size   = 2
      min_size       = 1
      max_size       = 3
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
