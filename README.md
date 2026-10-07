# java-eks-project

Full-stack Product Catalog application deployed on AWS EKS with complete CI/CD pipeline.

## Repos

| Repo | Purpose |
|------|---------|
| [java-eks-project](https://github.com/santhoshsanu/java-eks-project) | Application code + K8s manifests + Monitoring |
| [java-eks-infra](https://github.com/santhoshsanu/java-eks-infra) | Terraform infrastructure (EKS, ECR, VPC, IAM) |

## Project Structure

```
java-eks-project/
├── backend/          ← Spring Boot 3 + Java 17 (Gradle)
├── frontend/         ← React 18 + Vite + Nginx
├── k8s/              ← Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── backend-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   └── monitoring/   ← OTEL + Prometheus + Grafana
├── docs/             ← Setup guides
└── .github/
    └── workflows/
        └── pipeline.yml  ← CI/CD pipeline
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Spring Boot 3.2, Java 17, Gradle 8.5 |
| Frontend | React 18, Vite 5, Nginx |
| Database | H2 In-Memory |
| Container | Docker (multi-stage) |
| Registry | AWS ECR |
| Orchestration | AWS EKS (Kubernetes 1.31) |
| CI/CD | GitHub Actions |
| Security Scan | Trivy |
| Load Balancer | AWS ALB |
| Monitoring | OTEL Collector + Prometheus + Grafana |

## Pipeline

```
git push → GitHub Actions
  ├── Job 1: Gradle build + unit tests
  ├── Job 2: Docker build + Trivy scan + ECR push
  └── Job 3: Deploy to EKS + verify
```

## Infrastructure

Managed separately in → [java-eks-infra](https://github.com/santhoshsanu/java-eks-infra)
