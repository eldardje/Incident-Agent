output "table_names" {
  description = "DynamoDB table names keyed by logical table id."
  value = {
    incidents               = aws_dynamodb_table.incidents.name
    incident_comments       = aws_dynamodb_table.incident_comments.name
    incident_events         = aws_dynamodb_table.incident_events.name
    alarm_sources           = aws_dynamodb_table.alarm_sources.name
    ai_analysis             = aws_dynamodb_table.ai_analysis.name
    incident_config         = aws_dynamodb_table.incident_config.name
    config_log_groups       = aws_dynamodb_table.config_log_groups.name
    config_email_recipients = aws_dynamodb_table.config_email_recipients.name
    users                   = aws_dynamodb_table.users.name
    orgs                    = aws_dynamodb_table.orgs.name
    audit_log               = aws_dynamodb_table.audit_log.name
  }
}

output "table_arns" {
  description = "DynamoDB table ARNs keyed by logical table id."
  value = {
    incidents               = aws_dynamodb_table.incidents.arn
    incident_comments       = aws_dynamodb_table.incident_comments.arn
    incident_events         = aws_dynamodb_table.incident_events.arn
    alarm_sources           = aws_dynamodb_table.alarm_sources.arn
    ai_analysis             = aws_dynamodb_table.ai_analysis.arn
    incident_config         = aws_dynamodb_table.incident_config.arn
    config_log_groups       = aws_dynamodb_table.config_log_groups.arn
    config_email_recipients = aws_dynamodb_table.config_email_recipients.arn
    users                   = aws_dynamodb_table.users.arn
    orgs                    = aws_dynamodb_table.orgs.arn
    audit_log               = aws_dynamodb_table.audit_log.arn
  }
}
