# Bootstrap Scripts

These Terraform configurations set up the foundational AWS infrastructure needed for Terraform remote state and GitHub Actions integration.

## Files

- **backend-setup.tf** - Creates S3 bucket and DynamoDB table for Terraform state
- **github-oidc-setup.tf** - Creates OIDC provider and IAM role for GitHub Actions

## Quick Start

### 1. Set up Terraform Backend (Run First)

```bash
cd bootstrap

# Create S3 + DynamoDB for state management
terraform init
terraform apply -auto-approve

# Note the outputs
terraform output
```

Outputs you'll need:
- `state_bucket_name` - For backend.tf configuration
- `state_bucket_arn` - For OIDC setup
- `dynamodb_table_name` - For backend.tf configuration

### 2. Set up GitHub OIDC (Recommended)

Create `terraform.tfvars`:

```hcl
github_org         = "your-github-username"
github_repo        = "your-repo-name"
state_bucket_arn   = "arn:aws:s3:::terraform-state-dataingestion"
dynamodb_table_arn = "arn:aws:dynamodb:us-east-1:123456789:table/dataingestion-terraform-state-lock"
```

Apply:

```bash
terraform init
terraform apply -auto-approve

# Save this ARN for GitHub secrets
terraform output github_actions_role_arn
```

### 3. Configure GitHub

Add to GitHub Secrets:
- `AWS_ROLE_ARN` = Output from step 2

### 4. Update Backend Config

Edit `../envs/dev/backend.tf` and uncomment the backend block:

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

### 5. Initialize Remote Backend

```bash
cd ../envs/dev
terraform init  # Will migrate state to S3
```

## Important Notes

- Run `backend-setup.tf` **before** `github-oidc-setup.tf`
- These bootstrap scripts use **local state** (not remote)
- Keep the bootstrap state files safe - you'll need them to make changes
- Consider storing bootstrap state in a separate S3 bucket for safety

## Customization

### Change S3 Bucket Name

Edit `backend-setup.tf`:

```hcl
variable "state_bucket_name" {
  default = "your-unique-bucket-name"  # Must be globally unique
}
```

### Restrict GitHub Role to Main Branch Only

Edit `github-oidc-setup.tf`:

```hcl
condition {
  test     = "StringLike"
  variable = "token.actions.githubusercontent.com:sub"
  values   = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"]
}
```

### Scope Down IAM Permissions

The current policy gives broad permissions. For production, scope down to only required services:

```hcl
actions = [
  "s3:*",           # Only S3
  "glue:*",         # Only Glue
  "athena:*",       # Only Athena
  # etc.
]
```
