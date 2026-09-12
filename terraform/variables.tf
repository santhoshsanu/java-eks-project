# ─── General ────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "java-eks-project"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

# ─── VPC ─────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ) — EKS nodes live here"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to use (must match region)"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

# ─── EKS ─────────────────────────────────────────────────────────────────────

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "java-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes (t3.small minimum for K8s system pods)"
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

# ─── ECR ─────────────────────────────────────────────────────────────────────

variable "ecr_backend_repo_name" {
  description = "ECR repository name for the backend image"
  type        = string
  default     = "java-eks-backend"
}

variable "ecr_frontend_repo_name" {
  description = "ECR repository name for the frontend image"
  type        = string
  default     = "java-eks-frontend"
}

# ─── Jenkins EC2 ─────────────────────────────────────────────────────────────

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "t3.small"
}

variable "jenkins_ami_id" {
  description = "AMI ID for Jenkins EC2 (Ubuntu 22.04 LTS in ap-south-1)"
  type        = string
  default     = "ami-0f58b397bc5c1f2e8"  # Ubuntu 22.04 LTS ap-south-1
}

variable "jenkins_key_pair_name" {
  description = "EC2 Key Pair name for SSH access to Jenkins server"
  type        = string
  default     = "jenkins-keypair"
}

variable "your_ip_cidr" {
  description = "Your public IP in CIDR notation for SSH access to Jenkins (e.g. 203.0.113.10/32)"
  type        = string
  default     = "0.0.0.0/0"  # CHANGE THIS to your IP for security
}
