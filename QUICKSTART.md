# Quick Start Guide: GitHub → AWS Terraform Deployment

## 🎯 Goal
Set up automated Terraform deployments from GitHub Actions to AWS using OIDC (no long-lived credentials).

## 📋 Prerequisites Checklist

- [ ] AWS CLI installed and configured with admin access
- [ ] Terraform v1.5+ installed
- [ ] GitHub repository created
- [ ] Local clone of the repository

## 🚀 5-Step Setup

### Step 1: Create AWS Infrastructure for Terraform State (5 min)

```bash
cd "terraform code/bootstrap"

# Edit the bucket name to be globally unique
nano backend-setup.tf  # Change state_bucket_name variable

# Deploy
terraform init
terraform apply -auto-approve

# SAVE THESE OUTPUTS - You'll need them
terraform output -json > backend-outputs.json
```

### Step 2: Set up GitHub OIDC for AWS (5 min)

```bash
# Still in bootstrap directory
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your GitHub info
nano terraform.tfvars

# Update these values:
# - github_org: your GitHub username or org
# - github_repo: your repository name
# - state_bucket_arn: from backend-outputs.json
# - dynamodb_table_arn: from backend-outputs.json

# Deploy
terraform init
terraform apply -auto-approve

# SAVE THIS - You need it for GitHub
terraform output github_actions_role_arn
```

### Step 3: Configure GitHub Secrets (2 min)

1. Go to your GitHub repo
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add:
   - Name: `AWS_ROLE_ARN`
   - Value: (paste the role ARN from Step 2)

### Step 4: Enable Remote Backend (3 min)

```bash
cd ../envs/dev

# Edit backend.tf and uncomment the backend block
nano backend.tf

# Update with values from Step 1:
# - bucket: Use state_bucket_name
# - dynamodb_table: Use dynamodb_table_name

# Initialize remote backend
terraform init
# When prompted, type 'yes' to migrate local state to S3
```

### Step 5: Push to GitHub and Test (2 min)

```bash
cd ../..

# Add and commit all new files
git add .
git commit -m "Add GitHub Actions CI/CD for Terraform"
git push origin main

# Watch the GitHub Actions workflow run
# Go to: https://github.com/YOUR_ORG/YOUR_REPO/actions
```

## ✅ Verification

### Test the PR Workflow

```bash
# Create a test branch
git checkout -b test-cicd

# Make a small change (e.g., add a comment to envs/dev/main.tf)
echo "# Test change" >> envs/dev/main.tf

# Push and create PR
git add envs/dev/main.tf
git commit -m "Test: verify CI/CD workflow"
git push origin test-cicd

# Go to GitHub and create a Pull Request
# You should see:
# ✅ Terraform plan runs automatically
# ✅ Plan is posted as a comment on the PR
```

### Test the Apply Workflow

```bash
# Merge the PR in GitHub UI
# You should see:
# ✅ Terraform apply runs automatically on main branch
# ✅ Infrastructure is deployed to AWS
```

## 📊 What You Get

### On Every Pull Request:
- ✅ Terraform format check
- ✅ Terraform validation
- ✅ Terraform plan
- ✅ Plan posted as PR comment

### On Merge to Main:
- ✅ Terraform apply (auto-approved)
- ✅ Infrastructure deployed to AWS
- ✅ Outputs displayed in logs

## 🔒 Security Features

- ✅ No long-lived AWS credentials in GitHub
- ✅ Temporary credentials via OIDC
- ✅ Terraform state encrypted in S3
- ✅ State locking via DynamoDB
- ✅ Optional: GitHub environment protection rules

## 🛠️ Customization

### Add Manual Approval for Production

1. Go to **Settings** → **Environments** in GitHub
2. Create environment named `dev`
3. Enable **Required reviewers**
4. The workflow already uses this environment

### Deploy to Multiple Environments

Copy the workflow files and change the working directory:

```yaml
# .github/workflows/terraform-staging.yml
working-directory: ./envs/staging
```

## 📚 Full Documentation

See [GITHUB_AWS_SETUP.md](GITHUB_AWS_SETUP.md) for:
- Alternative setup using IAM access keys
- Detailed troubleshooting
- Security best practices
- Multi-environment deployments

## 🆘 Common Issues

### "Error: Bucket not found"
- Check the bucket name in `backend.tf` matches what you created
- Verify you're using the correct AWS region

### "Error: failed to assume role"
- Verify `AWS_ROLE_ARN` secret is set correctly in GitHub
- Check the role ARN includes your actual AWS account ID
- Ensure your GitHub org/repo names in OIDC setup are correct

### "Error: state lock"
- Someone else is running Terraform at the same time
- Wait a few minutes and try again
- Or manually unlock: `terraform force-unlock <LOCK_ID>`

## 📞 Need Help?

Check the detailed guide: [GITHUB_AWS_SETUP.md](GITHUB_AWS_SETUP.md)
