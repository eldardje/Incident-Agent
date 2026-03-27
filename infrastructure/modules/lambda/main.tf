data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  function_base_names = {
    normalizer = "normalizer"
    analyzer   = "analyzer"
    config_api = "config-api"
  }

  handler_map = {
    normalizer = "handler.lambda_handler"
    analyzer   = "handler.lambda_handler"
    config_api = "handler.lambda_handler"
  }

  runtime_map = {
    normalizer = "python3.12"
    analyzer   = "python3.12"
    config_api = "python3.12"
  }

  deployable_functions = var.create_functions ? {
    for key, path in var.package_paths :
    key => path if trim(path) != ""
  } : {}

  function_names = {
    for key, base_name in local.function_base_names :
    key => "${var.name_prefix}-${base_name}"
  }

  log_group_arns = {
    for key, function_name in local.function_names :
    key => "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${function_name}:*"
  }

  table_arns = [
    for table_name in values(var.table_names) :
    "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${table_name}"
  ]

  table_index_arns = [
    for table_name in values(var.table_names) :
    "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${table_name}/index/*"
  ]
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.function_base_names

  name              = "/aws/lambda/${local.function_names[each.key]}"
  retention_in_days = 14
  tags              = var.tags
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.name_prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid = "CloudWatchLogs"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = values(local.log_group_arns)
  }

  statement {
    sid = "DynamoAccess"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ]

    resources = concat(local.table_arns, local.table_index_arns)
  }

  statement {
    sid = "SecretsAccess"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = values(var.secret_arns)
  }

  statement {
    sid = "SNSPublish"

    actions   = ["sns:Publish"]
    resources = [var.incident_topic_arn]
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "${var.name_prefix}-lambda-policy"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_sns_topic_subscription" "normalizer" {
  count = contains(keys(local.deployable_functions), "normalizer") ? 1 : 0

  topic_arn = var.incident_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.functions["normalizer"].arn
}

resource "aws_lambda_permission" "sns_invoke_normalizer" {
  count = contains(keys(local.deployable_functions), "normalizer") ? 1 : 0

  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions["normalizer"].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.incident_topic_arn
}

resource "aws_lambda_function" "functions" {
  for_each = local.deployable_functions

  function_name    = local.function_names[each.key]
  role             = aws_iam_role.lambda_exec.arn
  runtime          = local.runtime_map[each.key]
  handler          = local.handler_map[each.key]
  filename         = each.value
  source_code_hash = filebase64sha256(each.value)
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      ENVIRONMENT                   = var.environment
      INCIDENTS_TABLE               = lookup(var.table_names, "incidents", "")
      INCIDENT_CONFIG_TABLE         = lookup(var.table_names, "incident_config", "")
      INCIDENT_EVENTS_TABLE         = lookup(var.table_names, "incident_events", "")
      INCIDENT_COMMENTS_TABLE       = lookup(var.table_names, "incident_comments", "")
      ALARM_SOURCES_TABLE           = lookup(var.table_names, "alarm_sources", "")
      AI_ANALYSIS_TABLE             = lookup(var.table_names, "ai_analysis", "")
      CONFIG_LOG_GROUPS_TABLE       = lookup(var.table_names, "config_log_groups", "")
      CONFIG_EMAIL_RECIPIENTS_TABLE = lookup(var.table_names, "config_email_recipients", "")
      USERS_TABLE                   = lookup(var.table_names, "users", "")
      ORGS_TABLE                    = lookup(var.table_names, "orgs", "")
      AUDIT_LOG_TABLE               = lookup(var.table_names, "audit_log", "")
      SLACK_WEBHOOK_SECRET_ARN      = lookup(var.secret_arns, "slack_webhook", "")
      SES_SECRET_ARN                = lookup(var.secret_arns, "ses_credentials", "")
      INCIDENT_TOPIC_ARN            = var.incident_topic_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = var.tags
}
