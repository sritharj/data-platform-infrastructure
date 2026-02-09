# Connecting GitHub to AWS for Terraform Deployments

This guide will help you set up automated Terraform deployments from GitHub Actions to AWS.

## Overview

You have two options for authentication:
1. **OIDC (Recommended)** - Uses temporary credentials, more secure
2. **IAM Access Keys** - Simpler setup but uses long-lived credentials

## Prerequisites

- AWS CLI configured locally with admin permissions
- GitHub repository created and code pushed
- Terraform installed locally (v1.5+)

---

## Option 1: OIDC Setup (Recommended)

### Step 1: Bootstrap AWS Infrastructure

First, create the S3 bucket and DynamoDB table for Terraform state:

```bash
cd bootstrap

# Initialize and apply the backend setup
terraform init
terraform apply -auto-approve

# Save the outputs - you'll need these
terraform output
```

**Save these outputs:**
- `state_bucket_name` - You'll use this in backend.tf
- `state_bucket_arn` - You'll use this in OIDC setup
- `dynamodb_table_name` - You'll use this in backend.tf

### Step 2: Set up GitHub OIDC Provider

Update the `github-oidc-setup.tf` file with your values:

```bash
# Create a terraform.tfvars file
cat > terraform.tfvars <<EOF
github_org          = "your-github-username-or-org"
github_repo         = "your-repo-name"
state_bucket_arn    = "arn:aws:s3:::terraform-state-dataingestion"  # From step 1
dynamodb_table_arn  = "arn:aws:dynamodb:us-east-1:123456789:table/dataingestion-terraform-state-lock"  # From step 1
EOF

# Apply the OIDC configuration
terraform init
terraform apply -auto-approve

# Save the role ARN - you'll need this for GitHub
terraform output github_actions_role_arn
```

### Step 3: Configure GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Add the following secret:
   - Name: `AWS_ROLE_ARN`
   - Value: The `github_actions_role_arn` from the previous step

### Step 4: Create GitHub Environment (Optional but Recommended)

For additional protection on the `main` branch:

1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Name it `dev`
4. Add protection rules:
   - ✅ Required reviewers (optional)
   - ✅ Wait timer (optional)

### Step 5: Update Backend Configuration

Update `envs/dev/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-dataingestion"  # From step 1
    key            = "dataingestion/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "dataingestion-terraform-state-lock"  # From step 1
  }
}
```

### Step 6: Push to GitHub

```bash
git add .
git commit -m "Add GitHub Actions CI/CD for Terraform"
git push origin main
```

### Step 7: Test the Workflow

1. Create a new branch and make a small change
2. Push the branch and create a pull request
3. GitHub Actions will run `terraform plan` and comment on the PR
4. Merge the PR to trigger `terraform apply`

---

## Option 2: IAM Access Keys (Simpler but Less Secure)

### Step 1: Bootstrap AWS Infrastructure

Same as Option 1, Step 1 above.

### Step 2: Create IAM User for GitHub Actions

```bash
# Create IAM user
aws iam create-user --user-name github-actions-terraform

# Create access keys
aws iam create-access-key --user-name github-actions-terraform

# Save the AccessKeyId and SecretAccessKey - you'll need these for GitHub
```

### Step 3: Attach Policy to IAM User

Create a policy file `github-actions-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-dataingestion",
        "arn:aws:s3:::terraform-state-dataingestion/*"
      ]
    },
    {
      "Sid": "TerraformStateLocking",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/dataingestion-terraform-state-lock"
    },
    {
      "Sid": "TerraformResourceManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "s3:*",
        "iam:*",
        "kms:*",
        "secretsmanager:*",
        "airflow:*",
        "glue:*",
        "lakeformation:*",
        "athena:*",
        "redshift:*",
        "redshift-serverless:*",
        "dynamodb:*",
        "events:*",
        "lambda:*",
        "logs:*",
        "cloudwatch:*",
        "sns:*"
      ],
      "Resource": "*"
    }
  ]
}
```

Attach the policy:

```bash
aws iam put-user-policy \
  --user-name github-actions-terraform \
  --policy-name TerraformFullAccess \
  --policy-document file://github-actions-policy.json
```

### Step 4: Configure GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Add the following secrets:
   - Name: `AWS_ACCESS_KEY_ID`
   - Value: The access key ID from step 2
   - Name: `AWS_SECRET_ACCESS_KEY`
   - Value: The secret access key from step 2

### Step 5: Use the IAM Keys Workflow

```bash
# Rename the example workflow
mv .github/workflows/terraform-apply-iam-keys.yml.example \
   .github/workflows/terraform-apply.yml

# Delete or disable the OIDC workflows if not using them
```

### Step 6: Update Backend Configuration

Same as Option 1, Step 5.

### Step 7: Push and Test

Same as Option 1, Steps 6-7.

---

## Workflow Behavior

### On Pull Request
- ✅ Runs `terraform fmt -check`
- ✅ Runs `terraform init`
- ✅ Runs `terraform validate`
- ✅ Runs `terraform plan`
- ✅ Comments the plan on the PR

### On Push to Main
- ✅ Runs `terraform init`
- ✅ Runs `terraform plan`
- ✅ Runs `terraform apply` (auto-approved)
- ✅ Outputs the Terraform outputs

---

## Environment-Specific Deployments

To deploy to multiple environments (dev, staging, prod):

1. Create separate workflow files for each environment:
   - `.github/workflows/terraform-dev.yml`
   - `.github/workflows/terraform-staging.yml`
   - `.github/workflows/terraform-prod.yml`

2. Each workflow should target a different directory:
   ```yaml
   working-directory: ./envs/dev
   # or
   working-directory: ./envs/staging
   # or
   working-directory: ./envs/prod
   ```

3. Use different GitHub environments for each with appropriate protection rules

---

## Troubleshooting

### Terraform Init Fails
- Check that the S3 bucket name in `backend.tf` matches the one you created
- Verify the DynamoDB table name is correct
- Ensure AWS credentials have permission to access S3 and DynamoDB

### GitHub Actions Can't Assume Role (OIDC)
- Verify the `AWS_ROLE_ARN` secret is set correctly in GitHub
- Check the trust policy on the IAM role allows your repo
- Ensure the OIDC provider thumbprints are current

### Permission Denied Errors
- Review the IAM policy attached to the role/user
- You may need to add additional permissions for specific AWS services
- Check for SCPs (Service Control Policies) that might be blocking actions

---

## Security Best Practices

1. **Use OIDC over IAM Keys** - Temporary credentials are more secure
2. **Limit IAM Permissions** - Use least privilege principle
3. **Enable Branch Protection** - Require PR reviews before merging to main
4. **Use GitHub Environments** - Add manual approval for production
5. **Audit Regularly** - Review CloudTrail logs for unexpected activity
6. **Rotate Credentials** - If using IAM keys, rotate them regularly
7. **Enable MFA** - For AWS accounts with administrative access

---

## Next Steps

After setting up the CI/CD pipeline:

1. **Configure Variables**: Update `envs/dev/terraform.tfvars` with your values
2. **Test Deployment**: Make a small change and test the workflow
3. **Add Environments**: Create staging and production environments
4. **Monitoring**: Set up notifications for failed deployments
5. **Cost Controls**: Add cost estimation tools like Infracost

---

## Additional Resources

- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform Backend Configuration](https://www.terraform.io/language/settings/backends/s3)
- [GitHub Actions for Terraform](https://learn.hashicorp.com/tutorials/terraform/github-actions)
