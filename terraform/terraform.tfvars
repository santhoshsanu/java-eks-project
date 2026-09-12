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

# ─── Jenkins EC2 ──────────────────────────────────────────────────────────────
jenkins_instance_type = "t3.small"
jenkins_ami_id        = "ami-0f58b397bc5c1f2e8"   # Ubuntu 22.04 LTS ap-south-1
jenkins_key_pair_name = "jenkins-keypair"

# IMPORTANT: Replace with your actual public IP to restrict SSH/UI access
# Find your IP at: https://checkip.amazonaws.com
your_ip_cidr = "0.0.0.0/0"
