# Step 5 — Jenkins Setup & Pipeline Configuration

## Overview
Jenkins is already installed on EC2 via Terraform bootstrap script.
This guide covers: initial setup → plugins → credentials → pipeline job → GitHub webhook.

---

## Part A — Access Jenkins

1. Get Jenkins URL from Terraform output:
   ```bash
   terraform output jenkins_url
   # Example: http://13.200.67.216:8080
   ```

2. Open in browser. You'll see the "Unlock Jenkins" screen.

3. SSH into Jenkins server to get initial password:
   ```bash
   ssh -i jenkins-keypair.pem ubuntu@13.200.67.216
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

4. Paste the password → Click **Install suggested plugins** → Create admin user.

---

## Part B — Install Required Plugins

1. Jenkins → **Manage Jenkins** → **Plugins** → **Available plugins**
2. Search and install each plugin from `jenkins/plugins.txt`
3. Key plugins to install:
   - `Pipeline` (workflow-aggregator)
   - `Git` + `GitHub` + `GitHub Branch Source`
   - `Docker Pipeline` (docker-workflow)
   - `AWS Credentials`
   - `Kubernetes CLI`
   - `Timestamper`
   - `Workspace Cleanup`
   - `JUnit`
   - `Blue Ocean` (optional — better UI)
4. Click **Restart after installation**

---

## Part C — Configure AWS Credentials in Jenkins

Jenkins EC2 has an IAM role (`jenkins-role`) attached via instance profile,
so it can talk to ECR and EKS **without storing any keys**.

Verify the role is working on Jenkins server:
```bash
ssh -i jenkins-keypair.pem ubuntu@13.200.67.216
aws sts get-caller-identity
# Should show the jenkins-role ARN
```

If you prefer credential-based approach:
1. Jenkins → **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. Click **Add Credentials**
3. Kind: `AWS Credentials`
4. ID: `aws-credentials`
5. Access Key ID + Secret: from `jenkins-terraform-user`
6. Click **Save**

---

## Part D — Configure GitHub Credentials

1. Go to GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token (classic)**
3. Name: `jenkins-github-token`
4. Scopes: check `repo`, `admin:repo_hook`
5. Click **Generate token** — copy it immediately

6. Jenkins → **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
7. Click **Add Credentials**
8. Kind: `Username with password`
9. Username: `santhoshsanu`
10. Password: paste the GitHub token
11. ID: `github-credentials`
12. Click **Save**

---

## Part E — Create the Pipeline Job

1. Jenkins → **New Item**
2. Name: `product-catalog-pipeline`
3. Type: **Pipeline** → Click **OK**

4. Under **General**:
   - Check **GitHub project**
   - Project URL: `https://github.com/santhoshsanu/java-eks-project`

5. Under **Build Triggers**:
   - Check **GitHub hook trigger for GITScm polling**

6. Under **Pipeline**:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/santhoshsanu/java-eks-project.git`
   - Credentials: select `github-credentials`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

7. Click **Save**

---

## Part F — Configure GitHub Webhook

This triggers Jenkins automatically on every `git push`.

1. Go to your GitHub repo → **Settings** → **Webhooks** → **Add webhook**
2. Payload URL: `http://13.200.67.216:8080/github-webhook/`
3. Content type: `application/json`
4. Which events: **Just the push event**
5. Check **Active**
6. Click **Add webhook**

Verify: GitHub will send a ping — look for a green tick next to the webhook.

---

## Part G — Run the Pipeline Manually (First Time)

1. Jenkins → `product-catalog-pipeline` → **Build Now**
2. Click the build number → **Console Output** to watch live logs

### Expected Stage Flow:
```
✅ Checkout              (~10s)
✅ Build Backend         (~2-3 min — Gradle downloads dependencies first time)
✅ Unit Tests            (~30s)
✅ Docker Build          (~3-5 min)
✅ Trivy Scan            (~2-3 min)
✅ Push to ECR           (~2-3 min)
✅ Deploy to EKS         (~2-3 min)
✅ Verify                (~10s)
─────────────────────────
Total: ~15-20 min first run, ~8-10 min subsequent runs
```

---

## Part H — Get the Application URL

After successful pipeline run:
```bash
kubectl get ingress -n product-catalog
```

Output:
```
NAME                        CLASS   HOSTS   ADDRESS                                    PORTS
product-catalog-ingress     alb     *       k8s-xxx.ap-south-1.elb.amazonaws.com       80
```

Open the ADDRESS in your browser → your Product Catalog app is live!

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `gradlew: Permission denied` | Add `sh 'chmod +x gradlew'` before gradle commands — already in Jenkinsfile |
| `docker: command not found` | Jenkins user not in docker group — run: `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins` |
| `kubectl: Unauthorized` | IAM role not attached to Jenkins EC2 — verify instance profile in AWS Console |
| `ImagePullBackOff` in K8s | ECR login expired — check Jenkins IAM role has ECR permissions |
| ALB address empty | Wait 2-3 min after deploy — ALB takes time to provision |
| Trivy scan fails build | Image has CRITICAL vulns — check `trivy-backend-report.txt` artifact |

---

## Checklist — Before Moving to Step 6

- [ ] Jenkins UI accessible at `http://13.200.67.216:8080`
- [ ] Plugins installed and Jenkins restarted
- [ ] GitHub credentials added
- [ ] Pipeline job created pointing to `Jenkinsfile`
- [ ] GitHub webhook configured
- [ ] First manual build triggered and successful
- [ ] App accessible via ALB URL
