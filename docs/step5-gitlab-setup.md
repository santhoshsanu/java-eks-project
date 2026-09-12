# Step 5 — GitLab CI/CD Setup Guide

## Overview
The Jenkins EC2 (provisioned by Terraform) is repurposed as a **GitLab Runner**.
GitLab CI/CD handles the pipeline — no Jenkins needed.

```
Developer pushes code → GitLab detects push → triggers .gitlab-ci.yml
→ GitLab Runner (EC2) picks up the job
→ Gradle build → Unit Tests → Docker build → Trivy scan
→ Push to ECR → Deploy to EKS → Verify
```

---

## Part A — Register GitLab Runner on EC2

### Step 1 — SSH into the Jenkins EC2
```bash
ssh -i jenkins-keypair.pem ubuntu@13.200.67.216
```

### Step 2 — Install GitLab Runner
```bash
# Download and install GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner -y

# Verify installation
gitlab-runner --version
```

### Step 3 — Get Runner Registration Token from GitLab
1. Go to → https://gitlab.com/santhoshgullapudi323/java-eks-project
2. Left sidebar → **Settings** → **CI/CD**
3. Expand **Runners** section
4. Click **New project runner**
5. Under Tags → type: `eks-runner` (must match tag in .gitlab-ci.yml)
6. Check **Run untagged jobs** → OFF
7. Click **Create runner**
8. Copy the **registration token** shown on screen

### Step 4 — Register the Runner
```bash
sudo gitlab-runner register
```
Answer the prompts:
```
GitLab instance URL: https://gitlab.com
Registration token:  <paste token from Step 3>
Description:         eks-runner
Tags:                eks-runner
Executor:            shell
```

### Step 5 — Start and enable the runner
```bash
sudo gitlab-runner start
sudo systemctl enable gitlab-runner

# Verify runner is active
sudo gitlab-runner status
```

### Step 6 — Add gitlab-runner user to docker group
```bash
sudo usermod -aG docker gitlab-runner
sudo systemctl restart gitlab-runner

# Test docker access
sudo -u gitlab-runner docker ps
```

---

## Part B — Configure AWS Permissions for Runner

The EC2 has the `jenkins-role` IAM instance profile attached (via Terraform).
This gives the runner access to ECR and EKS without storing any credentials.

Verify on the EC2:
```bash
aws sts get-caller-identity
# Should show: arn:aws:iam::889951088124:role/java-eks-project-jenkins-role
```

Configure kubectl for the runner user:
```bash
sudo -u gitlab-runner aws eks update-kubeconfig \
  --region ap-south-1 \
  --name java-eks-cluster
```

---

## Part C — Configure GitLab CI/CD Variables (Optional)

If you want to override any pipeline variables:
1. GitLab repo → **Settings** → **CI/CD** → **Variables**
2. Add variables as needed:

| Variable | Value | Purpose |
|----------|-------|---------|
| `AWS_REGION` | `ap-south-1` | Override default region |
| `TRIVY_SEVERITY` | `CRITICAL` | Only fail on CRITICAL (less strict) |

> Variables set here override the values in `.gitlab-ci.yml`

---

## Part D — Pipeline Stages Reference

| Stage | Job | What it does |
|-------|-----|-------------|
| build | build-backend | `./gradlew clean build` — produces JAR |
| test | unit-tests | `./gradlew test` — JUnit results published |
| docker-build | docker-build | Builds backend + frontend Docker images |
| trivy-scan | trivy-scan | Scans both images for CRITICAL/HIGH CVEs |
| push | push-to-ecr | Pushes `build-{N}` + `latest` tags to ECR |
| deploy | deploy-to-eks | `kubectl apply` — rolling deploy to EKS |
| verify | verify | Shows pods, services, ALB URL |
| .post | cleanup | Removes local Docker images from runner |

---

## Part E — Build Number

GitLab uses `CI_PIPELINE_IID` as the auto-incrementing build number.

Images are tagged as:
```
889951088124.dkr.ecr.ap-south-1.amazonaws.com/java-eks-backend:build-1
889951088124.dkr.ecr.ap-south-1.amazonaws.com/java-eks-backend:build-2
...
889951088124.dkr.ecr.ap-south-1.amazonaws.com/java-eks-backend:latest
```

---

## Part F — Trigger a Pipeline

### Automatic (on every push to main):
```bash
git add .
git commit -m "your message"
git push origin main
```
GitLab automatically detects the push and starts the pipeline.

### Manual trigger from GitLab UI:
1. GitLab repo → **CI/CD** → **Pipelines**
2. Click **Run pipeline**
3. Select branch `main` → Click **Run pipeline**

---

## Part G — View Pipeline Results

1. GitLab repo → **CI/CD** → **Pipelines**
2. Click the pipeline number to see all stages
3. Click any stage to see live logs
4. Trivy reports and test results available as **Artifacts** on each job

---

## Part H — Get the Application URL After Deploy

```bash
kubectl get ingress -n product-catalog
```
Output:
```
NAME                      CLASS  HOSTS  ADDRESS                                   PORTS
product-catalog-ingress   alb    *      k8s-xxx.ap-south-1.elb.amazonaws.com      80
```
Open the ADDRESS in your browser → Product Catalog app is live.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Runner shows offline | `sudo gitlab-runner restart` on EC2 |
| `docker: permission denied` | `sudo usermod -aG docker gitlab-runner && sudo systemctl restart gitlab-runner` |
| `kubectl: Unauthorized` | `sudo -u gitlab-runner aws eks update-kubeconfig --region ap-south-1 --name java-eks-cluster` |
| `gradlew: Permission denied` | Already handled in pipeline: `chmod +x gradlew` |
| Pipeline not triggering | Check runner tag is exactly `eks-runner` in both GitLab and `.gitlab-ci.yml` |
| ECR login fails | Verify IAM instance profile is attached to EC2 in AWS Console |
| ALB URL empty | Wait 2-3 min after deploy — ALB takes time to provision |

---

## Checklist — Before First Pipeline Run

- [ ] GitLab Runner installed on EC2
- [ ] Runner registered with tag `eks-runner`
- [ ] Runner status is `online` in GitLab UI
- [ ] `gitlab-runner` user is in `docker` group
- [ ] `aws sts get-caller-identity` works on EC2
- [ ] kubectl configured for `gitlab-runner` user
- [ ] Code pushed to GitLab `main` branch
- [ ] Pipeline triggered and all stages green
- [ ] App accessible via ALB URL
