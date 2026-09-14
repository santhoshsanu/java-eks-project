# Step 5 — GitHub Actions CI/CD Setup Guide

## Overview
GitHub Actions runs the pipeline on GitHub's own servers (ubuntu-latest).
No EC2, no Jenkins, no self-hosted runner needed.

```
Push to main branch
      ↓
GitHub Actions triggers automatically
      ↓
Job 1: Build Backend (Gradle) + Unit Tests
      ↓
Job 2: Docker Build → Trivy Scan → Push to ECR
      ↓
Job 3: Deploy to EKS → Verify
```

---

## Pipeline Jobs Summary

| Job | Trigger | What it does |
|-----|---------|-------------|
| `build-and-test` | push + PR | Gradle build + unit tests |
| `docker-build-scan-push` | push to main only | Docker build + Trivy + ECR push |
| `deploy-to-eks` | push to main only | kubectl apply + rollout + verify |

> Pull requests only run Job 1 (build + test) — no deploy on PRs.

---

## Part A — Add AWS Secrets to GitHub

GitHub Actions needs AWS credentials to push to ECR and deploy to EKS.
We use the `jenkins-terraform-user` access keys for this.

1. Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** — add these two:

| Secret Name | Value |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | Access key ID from `jenkins-terraform-user` |
| `AWS_SECRET_ACCESS_KEY` | Secret access key from `jenkins-terraform-user` |

> These are the same keys you configured in `aws configure` in Step 1.
> Find them in the CSV you downloaded when creating the IAM user.

---

## Part B — Push Code to GitHub

```powershell
cd c:\Users\santh\lokesh\scripts\java-eks-project

git add .
git commit -m "Switch to GitHub Actions pipeline"
git push -u origin main
```

When prompted:
- Username: `santhoshsanu`
- Password: your GitHub personal access token

---

## Part C — Watch the Pipeline Run

1. Go to → https://github.com/santhoshsanu/java-eks-project
2. Click the **Actions** tab
3. Click the running workflow to see live logs
4. Each job shows individual step logs

### Expected run times:
```
Job 1 - Build & Test    : ~3-4 min
Job 2 - Docker + Trivy  : ~8-10 min
Job 3 - Deploy to EKS   : ~3-4 min
─────────────────────────────────
Total                   : ~15-18 min
```

---

## Part D — Build Number

GitHub Actions uses `github.run_number` as the build number.
It auto-increments with every pipeline run.

Images are tagged:
```
889951088124.dkr.ecr.ap-south-1.amazonaws.com/java-eks-backend:build-1
889951088124.dkr.ecr.ap-south-1.amazonaws.com/java-eks-backend:build-2
889951088124.dkr.ecr.ap-south-1.amazonaws.com/java-eks-backend:latest
```

---

## Part E — Get Application URL After Deploy

```bash
kubectl get ingress -n product-catalog
```
Output:
```
NAME                      ADDRESS                                    PORTS
product-catalog-ingress   k8s-xxx.ap-south-1.elb.amazonaws.com      80
```
Open the ADDRESS in browser → Product Catalog is live.

---

## Part F — Trivy Scan Results

Trivy scan reports are uploaded as **artifacts** on every run.
To view them:
1. GitHub repo → **Actions** → click the run
2. Scroll to **Artifacts** section at the bottom
3. Download `trivy-reports-{N}` zip

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `AWS_ACCESS_KEY_ID not found` | Add secrets in GitHub repo Settings → Secrets |
| `ECR login failed` | Verify `jenkins-terraform-user` has ECR permissions |
| `kubectl Unauthorized` | Verify user has `eks:DescribeCluster` permission |
| `ImagePullBackOff` on EKS | Check ECR repo exists: `aws ecr describe-repositories` |
| Build fails on Gradle | Check Java version — pipeline uses Java 17 (temurin) |
| ALB URL empty after deploy | Wait 2-3 min — ALB takes time to provision |

---

## Checklist

- [ ] `AWS_ACCESS_KEY_ID` secret added to GitHub repo
- [ ] `AWS_SECRET_ACCESS_KEY` secret added to GitHub repo
- [ ] Code pushed to `main` branch
- [ ] Actions tab shows pipeline running
- [ ] All 3 jobs green ✅
- [ ] App accessible via ALB URL
