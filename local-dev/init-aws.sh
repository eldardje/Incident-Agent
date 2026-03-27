#!/bin/bash
# =============================================================================
# LocalStack init script — provisions AWS resources to mirror dev/staging/prod
# Runs automatically when LocalStack container becomes ready.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
PREFIX="incident-agent-local"
ENDPOINT="http://localhost:4566"

awslocal() {
  aws --endpoint-url="$ENDPOINT" --region="$REGION" "$@"
}

echo "=== Provisioning DynamoDB tables ==="

# incidents
awslocal dynamodb create-table \
  --table-name "${PREFIX}-incidents" \
  --attribute-definitions \
    AttributeName=incident_id,AttributeType=S \
    AttributeName=org_id,AttributeType=S \
    AttributeName=status,AttributeType=S \
    AttributeName=triggered_at,AttributeType=S \
  --key-schema AttributeName=incident_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    '[{"IndexName":"org-status-index","KeySchema":[{"AttributeName":"org_id","KeyType":"HASH"},{"AttributeName":"status","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},
      {"IndexName":"org-triggered-at-index","KeySchema":[{"AttributeName":"org_id","KeyType":"HASH"},{"AttributeName":"triggered_at","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]'

# incident_comments
awslocal dynamodb create-table \
  --table-name "${PREFIX}-incident-comments" \
  --attribute-definitions \
    AttributeName=comment_id,AttributeType=S \
    AttributeName=incident_id,AttributeType=S \
    AttributeName=org_id,AttributeType=S \
    AttributeName=created_at,AttributeType=S \
  --key-schema AttributeName=comment_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    '[{"IndexName":"incident-created-at-index","KeySchema":[{"AttributeName":"incident_id","KeyType":"HASH"},{"AttributeName":"created_at","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},
      {"IndexName":"org-created-at-index","KeySchema":[{"AttributeName":"org_id","KeyType":"HASH"},{"AttributeName":"created_at","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]'

# incident_events
awslocal dynamodb create-table \
  --table-name "${PREFIX}-incident-events" \
  --attribute-definitions \
    AttributeName=event_id,AttributeType=S \
    AttributeName=incident_id,AttributeType=S \
    AttributeName=org_id,AttributeType=S \
    AttributeName=created_at,AttributeType=S \
  --key-schema AttributeName=event_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    '[{"IndexName":"incident-created-at-index","KeySchema":[{"AttributeName":"incident_id","KeyType":"HASH"},{"AttributeName":"created_at","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},
      {"IndexName":"org-created-at-index","KeySchema":[{"AttributeName":"org_id","KeyType":"HASH"},{"AttributeName":"created_at","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]'

# alarm_sources
awslocal dynamodb create-table \
  --table-name "${PREFIX}-alarm-sources" \
  --attribute-definitions \
    AttributeName=alarm_source_id,AttributeType=S \
    AttributeName=org_id,AttributeType=S \
    AttributeName=alarm_name,AttributeType=S \
  --key-schema AttributeName=alarm_source_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    '[{"IndexName":"org-alarm-name-index","KeySchema":[{"AttributeName":"org_id","KeyType":"HASH"},{"AttributeName":"alarm_name","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]'

# ai_analysis
awslocal dynamodb create-table \
  --table-name "${PREFIX}-ai-analysis" \
  --attribute-definitions \
    AttributeName=analysis_id,AttributeType=S \
    AttributeName=incident_id,AttributeType=S \
    AttributeName=org_id,AttributeType=S \
    AttributeName=version,AttributeType=N \
  --key-schema AttributeName=analysis_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    '[{"IndexName":"incident-version-index","KeySchema":[{"AttributeName":"incident_id","KeyType":"HASH"},{"AttributeName":"version","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},
      {"IndexName":"org-incident-index","KeySchema":[{"AttributeName":"org_id","KeyType":"HASH"},{"AttributeName":"incident_id","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]'

# incident_config
awslocal dynamodb create-table \
  --table-name "${PREFIX}-incident-config" \
  --attribute-definitions AttributeName=org_id,AttributeType=S \
  --key-schema AttributeName=org_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# config_log_groups
awslocal dynamodb create-table \
  --table-name "${PREFIX}-config-log-groups" \
  --attribute-definitions \
    AttributeName=id,AttributeType=S \
    AttributeName=org_id,AttributeType=S \
    AttributeName=log_group_path,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    '[{"IndexName":"org-log-group-index","KeySchema":[{"AttributeName":"org_id","KeyType":"HASH"},{"AttributeName":"log_group_path","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]'

# config_email_recipients
awslocal dynamodb create-table \
  --table-name "${PREFIX}-config-email-recipients" \
  --attribute-definitions \
    AttributeName=id,AttributeType=S \
    AttributeName=org_id,AttributeType=S \
    AttributeName=email_address,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    '[{"IndexName":"org-email-address-index","KeySchema":[{"AttributeName":"org_id","KeyType":"HASH"},{"AttributeName":"email_address","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]'

# users
awslocal dynamodb create-table \
  --table-name "${PREFIX}-users" \
  --attribute-definitions \
    AttributeName=user_id,AttributeType=S \
    AttributeName=org_id,AttributeType=S \
    AttributeName=email,AttributeType=S \
  --key-schema AttributeName=user_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    '[{"IndexName":"org-email-index","KeySchema":[{"AttributeName":"org_id","KeyType":"HASH"},{"AttributeName":"email","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]'

# orgs
awslocal dynamodb create-table \
  --table-name "${PREFIX}-orgs" \
  --attribute-definitions AttributeName=org_id,AttributeType=S \
  --key-schema AttributeName=org_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# audit_log
awslocal dynamodb create-table \
  --table-name "${PREFIX}-audit-log" \
  --attribute-definitions \
    AttributeName=event_id,AttributeType=S \
    AttributeName=org_id,AttributeType=S \
    AttributeName=created_at,AttributeType=S \
    AttributeName=user_id,AttributeType=S \
  --key-schema AttributeName=event_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    '[{"IndexName":"org-created-at-index","KeySchema":[{"AttributeName":"org_id","KeyType":"HASH"},{"AttributeName":"created_at","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},
      {"IndexName":"user-created-at-index","KeySchema":[{"AttributeName":"user_id","KeyType":"HASH"},{"AttributeName":"created_at","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]'

echo "=== Provisioning SNS topic ==="

awslocal sns create-topic --name "${PREFIX}-incident-alarms"

# Subscribe n8n webhook to SNS topic (mirrors the Terraform SNS subscription)
awslocal sns subscribe \
  --topic-arn "arn:aws:sns:${REGION}:000000000000:${PREFIX}-incident-alarms" \
  --protocol http \
  --notification-endpoint "http://n8n:5678/webhook/cloudwatch-alarm"

echo "=== Provisioning Secrets Manager secrets ==="

awslocal secretsmanager create-secret \
  --name "${PREFIX}/slack/webhook" \
  --secret-string '{"webhook_url":"https://hooks.slack.com/services/PLACEHOLDER"}'

awslocal secretsmanager create-secret \
  --name "${PREFIX}/ses/credentials" \
  --secret-string '{"smtp_user":"test","smtp_password":"test","smtp_host":"localhost","smtp_port":"1025"}'

awslocal secretsmanager create-secret \
  --name "${PREFIX}/n8n/db-password" \
  --secret-string "n8n_local_dev"

awslocal secretsmanager create-secret \
  --name "${PREFIX}/n8n/encryption-key" \
  --secret-string "local-dev-encryption-key-change-me"

echo "=== Provisioning SES identity ==="

awslocal ses verify-email-identity --email-address "noreply@incident-agent.local"

echo "=== Provisioning CloudWatch Log Groups ==="

awslocal logs create-log-group --log-group-name "/aws/lambda/${PREFIX}-normalizer"
awslocal logs create-log-group --log-group-name "/aws/lambda/${PREFIX}-analyzer"
awslocal logs create-log-group --log-group-name "/aws/lambda/${PREFIX}-config-api"

echo ""
echo "============================================="
echo " LocalStack provisioning complete!"
echo " DynamoDB tables: 11"
echo " SNS topic: ${PREFIX}-incident-alarms"
echo " Secrets: 4"
echo " Log groups: 3"
echo "============================================="
echo ""
echo " n8n UI:        http://localhost:5678"
echo " LocalStack:    http://localhost:4566"
echo " PostgreSQL:    localhost:5432"
echo "============================================="
