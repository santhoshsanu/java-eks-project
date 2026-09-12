# Java EKS Full Stack Project

A full-stack Java (Spring Boot) + React application deployed on AWS EKS
using Jenkins CI/CD pipeline with Docker, Trivy scanning, and Terraform.

## Project Structure

```
java-eks-project/
├── backend/          ← Spring Boot 3 + Java 17 (Gradle)
├── frontend/         ← React (Vite)
├── k8s/              ← Kubernetes manifests (Deployments, Services, Ingress)
├── terraform/        ← EKS Cluster + ECR + VPC provisioning
├── jenkins/          ← Jenkinsfile CI/CD pipeline
├── iam/              ← IAM policies for Jenkins + Terraform
└── docs/             ← Setup guides and architecture docs
```

## Steps Completed
- [ ] Step 1: IAM Setup
- [ ] Step 2: Terraform - EKS + ECR
- [ ] Step 3: Spring Boot Backend
- [ ] Step 4: React Frontend
- [ ] Step 5: Dockerfiles
- [ ] Step 6: Jenkins Setup
- [ ] Step 7: Jenkinsfile Pipeline + Trivy
- [ ] Step 8: K8s Manifests
- [ ] Step 9: LoadBalancer + Domain
