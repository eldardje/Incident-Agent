resource "aws_dynamodb_table" "incidents" {
  name         = "${var.name_prefix}-incidents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "incident_id"

  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "incident_id"
    type = "S"
  }

  attribute {
    name = "org_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "triggered_at"
    type = "S"
  }

  global_secondary_index {
    name            = "org-status-index"
    hash_key        = "org_id"
    range_key       = "status"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "org-triggered-at-index"
    hash_key        = "org_id"
    range_key       = "triggered_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "incident_comments" {
  name         = "${var.name_prefix}-incident-comments"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "comment_id"

  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "comment_id"
    type = "S"
  }

  attribute {
    name = "incident_id"
    type = "S"
  }

  attribute {
    name = "org_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "incident-created-at-index"
    hash_key        = "incident_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "org-created-at-index"
    hash_key        = "org_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "incident_events" {
  name         = "${var.name_prefix}-incident-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "event_id"
    type = "S"
  }

  attribute {
    name = "incident_id"
    type = "S"
  }

  attribute {
    name = "org_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "incident-created-at-index"
    hash_key        = "incident_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "org-created-at-index"
    hash_key        = "org_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "alarm_sources" {
  name         = "${var.name_prefix}-alarm-sources"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "alarm_source_id"

  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "alarm_source_id"
    type = "S"
  }

  attribute {
    name = "org_id"
    type = "S"
  }

  attribute {
    name = "alarm_name"
    type = "S"
  }

  global_secondary_index {
    name            = "org-alarm-name-index"
    hash_key        = "org_id"
    range_key       = "alarm_name"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "ai_analysis" {
  name         = "${var.name_prefix}-ai-analysis"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "analysis_id"

  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "analysis_id"
    type = "S"
  }

  attribute {
    name = "incident_id"
    type = "S"
  }

  attribute {
    name = "org_id"
    type = "S"
  }

  attribute {
    name = "version"
    type = "N"
  }

  global_secondary_index {
    name            = "incident-version-index"
    hash_key        = "incident_id"
    range_key       = "version"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "org-incident-index"
    hash_key        = "org_id"
    range_key       = "incident_id"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "incident_config" {
  name         = "${var.name_prefix}-incident-config"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "org_id"

  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "org_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "config_log_groups" {
  name         = "${var.name_prefix}-config-log-groups"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "org_id"
    type = "S"
  }

  attribute {
    name = "log_group_path"
    type = "S"
  }

  global_secondary_index {
    name            = "org-log-group-index"
    hash_key        = "org_id"
    range_key       = "log_group_path"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "config_email_recipients" {
  name         = "${var.name_prefix}-config-email-recipients"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "org_id"
    type = "S"
  }

  attribute {
    name = "email_address"
    type = "S"
  }

  global_secondary_index {
    name            = "org-email-address-index"
    hash_key        = "org_id"
    range_key       = "email_address"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "users" {
  name         = "${var.name_prefix}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "org_id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "org-email-index"
    hash_key        = "org_id"
    range_key       = "email"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "orgs" {
  name         = "${var.name_prefix}-orgs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "org_id"

  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "org_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "audit_log" {
  name         = "${var.name_prefix}-audit-log"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  deletion_protection_enabled = var.enable_deletion_protection

  attribute {
    name = "event_id"
    type = "S"
  }

  attribute {
    name = "org_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  global_secondary_index {
    name            = "org-created-at-index"
    hash_key        = "org_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "user-created-at-index"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}
