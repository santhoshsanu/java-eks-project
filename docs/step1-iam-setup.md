# Step 1 — IAM Setup Guide

## What We Are Creating

| Resource | Purpose |
|----------|---------|
| IAM Policy: `JenkinsTerraformPolicy` | Grants Jenkins + Terraform permissions for EKS, ECR, EC2, S3, IAM |
| IAM User: `jenkins-terraform-user` | Programmatic user used by Jenkins and Terraform |
| IAM Role: `eks-cluster-role` | Role assumed by EKS control plane |
| IAM Role: `eks-node-role` | Role assumed by EKS worker nodes |

---

## Part A — Create the Jenkins/Terraform IAM Policy

1. Go to → https://console.aws.amazon.com/iam
2. Left sidebar → **Policies** → Click **Create policy**
3. Click the **JSON** tab
4. **Delete** everything in the editor
5. Open file: `iam/jenkins-terraform-policy.json` from this project
6. **Paste** the entire contents into the JSON editor
7. Click **Next**
8. Policy name: `JenkinsTerraformPolicy`
9. Description: `Policy for Jenkins CI/CD and Terraform EKS provisioning`
10. Click **Create policy**

---

## Part B — Create IAM User for Jenkins + Terraform

1. IAM → Left sidebar → **Users** → Click **Create user**
2. User name: `jenkins-terraform-user`
3. **Do NOT** check "Provide user access to the AWS Management Console"
4. Click **Next**
5. Select **Attach policies directly**
6. Search for `JenkinsTerraformPolicy` → check the box
7. Click **Next** → **Create user**

### Generate Access Keys for this user:
1. Click on `jenkins-terraform-user` → **Security credentials** tab
2. Scroll to **Access keys** → Click **Create access key**
3. Use case: **Command Line Interface (CLI)**
4. Check the confirmation checkbox → Click **Next**
5. Click **Create access key**
6. **IMPORTANT: Download the CSV file immediately** — you cannot see the secret key again
7. Save these safely:
   - Access Key ID: `AKIA...`
   - Secret Access Key: `...`

---

## Part C — Create EKS Cluster IAM Role

1. IAM → **Roles** → **Create role**
2. Trusted entity type: **AWS service**
3. Use case: **EKS** → Select **EKS - Cluster**
4. Click **Next** → **Next**
5. Role name: `eks-cluster-role`
6. Click **Create role**

> AWS automatically attaches `AmazonEKSClusterPolicy` to this role.

---

## Part D — Create EKS Node Group IAM Role

1. IAM → **Roles** → **Create role**
2. Trusted entity type: **AWS service**
3. Use case: **EC2**
4. Click **Next**
5. Search and attach these 3 policies:
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEKS_CNI_Policy`
   - `AmazonEC2ContainerRegistryReadOnly`
6. Click **Next**
7. Role name: `eks-node-role`
8. Click **Create role**

---

## Part E — Configure AWS CLI on Your Machine

### Install AWS CLI (if not installed)
Download from: https://aws.amazon.com/cli/
Or run in PowerShell (Windows):
```powershell
winget install -e --id Amazon.AWSCLI
```

### Configure credentials:
```bash
aws configure
```
Enter when prompted:
```
AWS Access Key ID:     <paste Access Key ID from Part B>
AWS Secret Access Key: <paste Secret Access Key from Part B>
Default region name:   ap-south-1      ← use your preferred region
Default output format: json
```

### Verify it works:
```bash
aws sts get-caller-identity
```
Expected output:
```json
{
    "UserId": "AIDA...",
    "Account": "889951088124",
    "Arn": "arn:aws:iam::889951088124:user/jenkins-terraform-user"
}
```

---

## Part F — Create S3 Bucket for Terraform State

This stores your Terraform state file remotely so it's safe and shareable.

1. Go to → https://s3.console.aws.amazon.com
2. Click **Create bucket**
3. Bucket name: `java-eks-project-tfstate-889951088124`
   *(must be globally unique — the account number at the end ensures this)*
4. Region: same as your preferred region (e.g., `ap-south-1`)
5. **Block all public access** → keep checked (default)
6. Enable **Bucket Versioning** → click Enable
7. Click **Create bucket**

---

## Part G — Create DynamoDB Table for Terraform Lock

This prevents two people (or two pipeline runs) from running Terraform simultaneously.

1. Go to → https://console.aws.amazon.com/dynamodb
2. Click **Create table**
3. Table name: `terraform-state-lock`
4. Partition key: `LockID` (type: String)
5. Table settings: **Default settings**
6. Click **Create table**

---

## Checklist — Before Moving to Step 2

- [ ] Policy `JenkinsTerraformPolicy` created
- [ ] User `jenkins-terraform-user` created with Access Key downloaded
- [ ] Role `eks-cluster-role` created
- [ ] Role `eks-node-role` created with 3 policies attached
- [ ] AWS CLI configured and `aws sts get-caller-identity` works
- [ ] S3 bucket `java-eks-project-tfstate-889951088124` created
- [ ] DynamoDB table `terraform-state-lock` created

Once all boxes are checked → tell me and we move to **Step 2: Terraform EKS + ECR**
