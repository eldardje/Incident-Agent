# Incident Agent Terraform (T-01)

This Terraform stack scaffolds the Incident Agent infrastructure for dev, staging, and prod using Terraform workspaces.

## Shared infrastructure reuse

This stack reuses existing shared infrastructure from the Career Platform:

- S3 backend state storage
- DynamoDB lock table for state locking (if configured)
- Existing GitHub OIDC provider and deploy role trust

The stack intentionally does not define resources to create a new OIDC provider or a new backend bucket.

## Workspace flow

```powershell
terraform init `
  -backend-config="bucket=<career-platform-state-bucket>" `
  -backend-config="key=incident-agent/terraform.tfstate" `
  -backend-config="region=us-east-1" `
  -backend-config="dynamodb_table=<career-platform-lock-table>"

terraform workspace new dev
terraform workspace select dev
terraform plan

terraform workspace new staging
terraform workspace select staging
terraform plan

terraform workspace new prod
terraform workspace select prod
terraform plan
```

## Notes

- Set `create_lambda_functions=true` when lambda zip artifacts are available.
- Set `deploy_ecs=true` and provide VPC/subnet/security group inputs to create ECS services.
- DynamoDB includes the full 11-table model from dbschema.html.
