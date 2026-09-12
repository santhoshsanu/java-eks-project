# AWS CLI Configuration Reference

## Credentials File Location
- Windows: `C:\Users\<your-username>\.aws\credentials`
- Linux/Mac: `~/.aws/credentials`

## Contents of credentials file (auto-created by `aws configure`):
```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
```

## Contents of config file:
```ini
[default]
region = ap-south-1
output = json
```

## Useful verification commands:
```bash
# Check who you are logged in as
aws sts get-caller-identity

# List S3 buckets (confirms S3 permissions work)
aws s3 ls

# List ECR repositories (will be empty initially)
aws ecr describe-repositories --region ap-south-1

# List EKS clusters (will be empty initially)
aws eks list-clusters --region ap-south-1
```

## Regions Quick Reference
| Region Name         | Region Code    |
|---------------------|----------------|
| Mumbai (India)      | ap-south-1     |
| Singapore           | ap-southeast-1 |
| US East (N.Virginia)| us-east-1      |
| US West (Oregon)    | us-west-2      |
| Europe (Ireland)    | eu-west-1      |

> Recommendation: Use `ap-south-1` (Mumbai) for lowest latency from India.
