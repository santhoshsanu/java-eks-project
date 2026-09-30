# ══════════════════════════════════════════════════════════════════════════════
#  Helm Releases — managed by Terraform
#  1. Metrics Server    — needed for HPA auto-scaling
#  2. ALB Controller    — needed for AWS Application Load Balancer via Ingress
# ══════════════════════════════════════════════════════════════════════════════

# ─── Kubernetes Service Account for ALB Controller ────────────────────────────
# Links the K8s service account to the IAM role via IRSA annotation

resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      # This annotation links the K8s service account to the IAM role
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller_role.arn
    }

    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
  }

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.alb_controller_policy
  ]
}

# ─── Metrics Server ───────────────────────────────────────────────────────────
# Required for HPA (Horizontal Pod Autoscaler) to work
# Collects CPU/memory metrics from nodes and pods

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.0"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"   # needed for EKS
  }

  depends_on = [aws_eks_node_group.main]
}

# ─── AWS Load Balancer Controller ─────────────────────────────────────────────
# Creates AWS ALB/NLB automatically when K8s Ingress/Service resources are applied
# Required for our ingress.yaml to create the Application Load Balancer

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"   # we created it above via kubernetes_service_account
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }

  set {
    name  = "replicaCount"
    value = "1"   # 1 replica saves resources on t3.small
  }

  depends_on = [
    kubernetes_service_account.alb_controller,
    helm_release.metrics_server,
    aws_eks_node_group.main
  ]
}
