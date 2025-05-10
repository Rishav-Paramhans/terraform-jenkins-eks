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

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Kubernetes provider block - This allows Terraform to communicate with your EKS cluster
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
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
resource "aws_iam_policy" "efs_csi_driver" {
  name        = "AmazonEKS_EFS_CSI_Driver_Policyy_${var.cluster_name}_v1"
  description = "IAM policy for EFS CSI driver to manage access points"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:CreateAccessPoint",
          "elasticfilesystem:DeleteAccessPoint",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:CreateMountTarget",
          "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:ModifyMountTargetSecurityGroups",
          "elasticfilesystem:DescribeFileSystemPolicy",
          "elasticfilesystem:DeleteMountTarget"
        ],
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role" "efs_csi_irsa" {
  name = "eks-efs-csi-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = module.eks.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "oidc.eks.us-east-1.amazonaws.com/id/9718D5D5301A5535E8C427506052A772:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
          }
        }
      }
    ]
  })
  depends_on = [module.eks]
}
resource "aws_iam_role_policy_attachment" "efs_csi_attach" {
  role       = aws_iam_role.efs_csi_irsa.name
  policy_arn = aws_iam_policy.efs_csi_driver.arn
}
output "efs_csi_irsa_role_arn" {
  value = aws_iam_role.efs_csi_irsa.arn
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
# --- EFS Security Group (allows NFS from EKS Nodes SG) ---
resource "aws_security_group" "efs" {
  name        = "efs_sg"
  description = "Allow NFS from EKS"
  vpc_id      = "vpc-01ca446be893bad0e"

  ingress {
    from_port                = 2049
    to_port                  = 2049
    protocol                 = "tcp"
    security_groups          = [aws_security_group.eks_nodes.id]  # Allow from EKS SG
    description              = "Allow NFS from EKS Nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs_sg"
  }
}

# --- EFS File System ---
resource "aws_efs_file_system" "this" {
  creation_token = "efs-for-eks"
  encrypted      = true

  tags = {
    Name = "eks-efs"
  }
}

# --- Mount Targets in Subnets ---
resource "aws_efs_mount_target" "subnet_a" {
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = "subnet-0ffd0950ec3de3b50"
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "subnet_b" {
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = "subnet-0932a11f28a59297c"
  security_groups = [aws_security_group.efs.id]
}

# --- EFS Access Point ---
resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id

  root_directory {
    path = "/ollama-data"
    creation_info {
      owner_uid   = 1001
      owner_gid   = 1001
      permissions = "700"
    }
  }

  tags = {
    Name = "eks-efs-ap"
  }
}

# --- Outputs for YAML usage ---
output "efs_file_system_id" {
  value = aws_efs_file_system.this.id
}

output "efs_access_point_id" {
  value = aws_efs_access_point.this.id
}


# --- Create PVC for Ollama models ---
#resource "kubernetes_persistent_volume_claim" "ollama_models" {
#  metadata {
#    name      = "ollama-models-pvc"
#    namespace = "default"
#  }

#  spec {
#    access_modes = ["ReadWriteOnce"]

#    resources {
#      requests = {
#        storage = "100Gi"
#      }
#    }

#    volume_name = "eks-cluster-pv"  # Reference your manually created PV here
#  }
#}


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
      #ami_type       = "amazon-eks-node-al2023-x86_64-nvidia-1.27-v20250501"             # ADD THIS LINE
      ami_type       = "AL2023_x86_64_NVIDIA"             # ADD THIS LINE
      instance_types = ["g4dn.xlarge"] # GPU support
      desired_size   = 1
      min_size       = 1
      max_size       = 4
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
  #depends_on = [kubernetes_persistent_volume_claim.ollama_models]  
  # Ensure PVC is created before EKS nodes
}

