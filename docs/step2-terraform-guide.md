# Step 2 — Terraform: EKS + ECR + Jenkins

## What Gets Created

| Resource | Details |
|----------|---------|
| VPC | 10.0.0.0/16 with 2 public + 2 private subnets |
| Internet Gateway + NAT Gateway | Public internet access |
| EKS Cluster | `java-eks-cluster` on Kubernetes 1.29 |
| EKS Node Group | 2x t3.medium worker nodes in private subnets |
| EKS Add-ons | coredns, kube-proxy, vpc-cni |
| IAM Roles | eks-cluster-role, eks-node-role, jenkins-role |
| ECR Repositories | `java-eks-backend` + `java-eks-frontend` |
| Jenkins EC2 | t3.medium Ubuntu 22.04 in public subnet |
| Jenkins EIP | Static public IP for Jenkins |
| S3 + DynamoDB | Terraform remote state (already created in Step 1) |

---

## Pre-flight Checklist

- [ ] AWS CLI configured (`aws sts get-caller-identity` works)
- [ ] Terraform installed (`terraform --version` shows >= 1.5.0)
- [ ] S3 bucket `java-eks-project-tfstate-889951088124` exists
- [ ] DynamoDB table `terraform-state-lock` exists
- [ ] EC2 Key Pair created (see below)

---

## Part A — Create EC2 Key Pair for Jenkins SSH

Run this in your terminal:
```bash
aws ec2 create-key-pair \
  --key-name jenkins-keypair \
  --region ap-south-1 \
  --query 'KeyMaterial' \
  --output text > jenkins-keypair.pem

# On Linux/Mac:
chmod 400 jenkins-keypair.pem

# On Windows PowerShell:
icacls jenkins-keypair.pem /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

> Store `jenkins-keypair.pem` safely — you need it to SSH into Jenkins.

---

## Part B — Install Terraform

### Windows (PowerShell):
```powershell
winget install --id Hashicorp.Terraform
```

### Verify:
```bash
terraform --version
# Should show: Terraform v1.5.x or higher
```

---

## Part C — Update your_ip_cidr (Recommended)

Find your public IP:
```bash
curl https://checkip.amazonaws.com
# Example output: 203.0.113.45
```

Edit `terraform/terraform.tfvars`:
```hcl
your_ip_cidr = "203.0.113.45/32"   # replace with your actual IP
```

---

## Part D — Run Terraform

Navigate to the terraform folder and run these commands **in order**:

### 1. Initialize Terraform (downloads providers, connects to S3 backend)
```bash
cd terraform
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
Backend "s3" is configured and connected.
```

### 2. Validate configuration
```bash
terraform validate
```
Expected: `Success! The configuration is valid.`

### 3. Plan — preview what will be created
```bash
terraform plan -out=tfplan
```
Review the output carefully. You should see:
- ~35-40 resources to add
- 0 to change, 0 to destroy

### 4. Apply — create the infrastructure
```bash
terraform apply tfplan
```
Type `yes` when prompted.

> ⏱️ This takes **15-20 minutes** — EKS cluster creation is the slow part. Let it run.

---

## Part E — After Apply Completes

### Configure kubectl to connect to EKS:
```bash
aws eks update-kubeconfig --region ap-south-1 --name java-eks-cluster
```

### Verify nodes are ready:
```bash
kubectl get nodes
```
Expected:
```
NAME                                STATUS   ROLES    AGE   VERSION
ip-10-0-10-xxx.ap-south-1.compute   Ready    <none>   2m    v1.29.x
ip-10-0-20-xxx.ap-south-1.compute   Ready    <none>   2m    v1.29.x
```

### Check Jenkins URL:
```bash
terraform output jenkins_url
# Example: http://13.233.xxx.xxx:8080
```

---

## Part F — Jenkins Initial Setup

1. Open the Jenkins URL in browser (wait ~5 min after apply for Jenkins to finish installing)
2. SSH into Jenkins to get the initial password:
   ```bash
   ssh -i jenkins-keypair.pem ubuntu@<jenkins-public-ip>
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
3. Paste the password in browser
4. Click **Install suggested plugins**
5. Create admin user
6. Jenkins is ready!

---

## Useful Terraform Output Values

After `terraform apply`:
```bash
terraform output eks_cluster_name        # java-eks-cluster
terraform output eks_cluster_endpoint    # EKS API URL
terraform output ecr_backend_repo_url    # ECR URL for backend
terraform output ecr_frontend_repo_url   # ECR URL for frontend
terraform output jenkins_url             # Jenkins Web UI
terraform output jenkins_public_ip       # Jenkins server IP
terraform output eks_kubeconfig_command  # kubectl config command
```

---

## Tear Down (when not needed — saves cost)

```bash
terraform destroy
```
This removes ALL resources including EKS, Jenkins EC2, VPC, ECR.
> ⚠️ ECR images and S3 state file are preserved even after destroy.

---

## Checklist — Before Moving to Step 3

- [ ] `terraform apply` completed successfully
- [ ] `kubectl get nodes` shows 2 Ready nodes
- [ ] Jenkins URL is accessible in browser
- [ ] Jenkins initial setup done
- [ ] `terraform output ecr_backend_repo_url` gives a valid URL

Once all checked → tell me and we move to **Step 3: Spring Boot Backend (Gradle)**
