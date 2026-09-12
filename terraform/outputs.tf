# ─── VPC Outputs ──────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

# ─── EKS Outputs ─────────────────────────────────────────────────────────────

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = aws_eks_cluster.main.version
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "eks_kubeconfig_command" {
  description = "Run this command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

# ─── ECR Outputs ──────────────────────────────────────────────────────────────

output "ecr_backend_repo_url" {
  description = "ECR URL for backend image — use this in Jenkinsfile"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repo_url" {
  description = "ECR URL for frontend image — use this in Jenkinsfile"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_registry" {
  description = "ECR registry base URL (account.dkr.ecr.region.amazonaws.com)"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# ─── Jenkins Outputs ──────────────────────────────────────────────────────────

output "jenkins_public_ip" {
  description = "Jenkins server public IP (Elastic IP)"
  value       = aws_eip.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins Web UI URL"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins server"
  value       = "ssh -i ${var.jenkins_key_pair_name}.pem ubuntu@${aws_eip.jenkins.public_ip}"
}

output "jenkins_initial_password_command" {
  description = "Run this on Jenkins server to get initial admin password"
  value       = "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN — used for IAM Roles for Service Accounts"
  value       = aws_iam_openid_connect_provider.eks.arn
}

# ─── Data Source ──────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
