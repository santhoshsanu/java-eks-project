# ─── General ──────────────────────────────────────────────────────────────────
aws_region   = "ap-south-1"
project_name = "java-eks-project"
environment  = "dev"

# ─── VPC ──────────────────────────────────────────────────────────────────────
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
availability_zones   = ["ap-south-1a", "ap-south-1b"]

# ─── EKS ──────────────────────────────────────────────────────────────────────
cluster_name       = "java-eks-cluster"
cluster_version    = "1.31"
node_instance_type = "t3.small"   # minimum viable for EKS (t2.micro too small for K8s)
node_desired_size  = 1
node_min_size      = 1
node_max_size      = 2

# ─── ECR ──────────────────────────────────────────────────────────────────────
ecr_backend_repo_name  = "java-eks-backend"
ecr_frontend_repo_name = "java-eks-frontend"

