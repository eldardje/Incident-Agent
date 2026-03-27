data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  count = var.deploy_ecs ? 1 : 0

  name = "${var.name_prefix}-cluster"
  tags = var.tags
}

# -----------------------------------------------------------------------------
# IAM - Task Execution Role (pulls images, reads secrets)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "task_execution_role" {
  count = var.deploy_ecs ? 1 : 0

  name               = "${var.name_prefix}-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  count = var.deploy_ecs ? 1 : 0

  role       = aws_iam_role.task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_exec_secrets" {
  statement {
    sid = "SecretsAccess"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = values(var.secret_arns)
  }
}

resource "aws_iam_role_policy" "ecs_exec_secrets" {
  count = var.deploy_ecs ? 1 : 0

  name   = "${var.name_prefix}-ecs-exec-secrets"
  role   = aws_iam_role.task_execution_role[0].id
  policy = data.aws_iam_policy_document.ecs_exec_secrets.json
}

# -----------------------------------------------------------------------------
# IAM - Task Role (runtime permissions for containers)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "task_role" {
  count = var.deploy_ecs ? 1 : 0

  name               = "${var.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "ecs_task_policy" {
  statement {
    sid       = "SNSPublish"
    actions   = ["sns:Publish"]
    resources = [var.incident_topic_arn]
  }

  statement {
    sid = "LambdaInvoke"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.name_prefix}-*"
    ]
  }

  statement {
    sid = "SESsend"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  count = var.deploy_ecs ? 1 : 0

  name   = "${var.name_prefix}-ecs-task-policy"
  role   = aws_iam_role.task_role[0].id
  policy = data.aws_iam_policy_document.ecs_task_policy.json
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  name              = "/ecs/${var.name_prefix}/n8n"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "ui" {
  count = var.deploy_ecs ? 1 : 0

  name              = "/ecs/${var.name_prefix}/ui"
  retention_in_days = 14
  tags              = var.tags
}

# -----------------------------------------------------------------------------
# EFS - Persistent storage for n8n
# -----------------------------------------------------------------------------
resource "aws_efs_file_system" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  creation_token = "${var.name_prefix}-n8n-efs"
  encrypted      = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-n8n-efs"
  })
}

resource "aws_efs_mount_target" "n8n" {
  count = var.deploy_ecs ? length(var.subnet_ids) : 0

  file_system_id  = aws_efs_file_system.n8n[0].id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = var.efs_security_group_ids
}

resource "aws_efs_access_point" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  file_system_id = aws_efs_file_system.n8n[0].id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/n8n-data"

    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL - n8n execution history
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  name       = "${var.name_prefix}-n8n-db"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_db_instance" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  identifier     = "${var.name_prefix}-n8n"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_encrypted     = true

  db_name  = "n8n"
  username = "n8n_admin"
  password = var.n8n_db_password

  db_subnet_group_name   = aws_db_subnet_group.n8n[0].name
  vpc_security_group_ids = var.rds_security_group_ids

  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.name_prefix}-n8n-final"
  backup_retention_period   = 7

  tags = var.tags
}

# -----------------------------------------------------------------------------
# ALB - Protect n8n UI with basic auth via Cognito
# -----------------------------------------------------------------------------
resource "aws_lb" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  name               = "${var.name_prefix}-n8n-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.alb_security_group_ids
  subnets            = var.public_subnet_ids

  tags = var.tags
}

resource "aws_lb_target_group" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  name        = "${var.name_prefix}-n8n-tg"
  port        = 5678
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = var.tags
}

resource "aws_lb_listener" "n8n_https" {
  count = var.deploy_ecs && var.n8n_certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.n8n[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.n8n_certificate_arn

  default_action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn       = aws_cognito_user_pool.n8n[0].arn
      user_pool_client_id = aws_cognito_user_pool_client.n8n[0].id
      user_pool_domain    = aws_cognito_user_pool_domain.n8n[0].domain
    }
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.n8n[0].arn
  }
}

resource "aws_lb_listener" "n8n_http" {
  count = var.deploy_ecs ? 1 : 0

  load_balancer_arn = aws_lb.n8n[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Webhook listener rule - bypasses auth for SNS webhook path
resource "aws_lb_listener_rule" "n8n_webhook" {
  count = var.deploy_ecs && var.n8n_certificate_arn != "" ? 1 : 0

  listener_arn = aws_lb_listener.n8n_https[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.n8n[0].arn
  }

  condition {
    path_pattern {
      values = ["/webhook/*", "/webhook-waiting/*"]
    }
  }
}

# -----------------------------------------------------------------------------
# Cognito - Basic auth for n8n ALB
# -----------------------------------------------------------------------------
resource "aws_cognito_user_pool" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  name = "${var.name_prefix}-n8n-auth"

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_domain" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  domain       = "${var.name_prefix}-n8n"
  user_pool_id = aws_cognito_user_pool.n8n[0].id
}

resource "aws_cognito_user_pool_client" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  name         = "${var.name_prefix}-n8n-alb-client"
  user_pool_id = aws_cognito_user_pool.n8n[0].id

  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  supported_identity_providers         = ["COGNITO"]

  callback_urls = [
    "https://${var.n8n_domain}/oauth2/idpresponse"
  ]
}

# -----------------------------------------------------------------------------
# n8n Task Definition - with EFS, RDS, and credential env vars
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  family                   = "${var.name_prefix}-n8n"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.task_execution_role[0].arn
  task_role_arn            = aws_iam_role.task_role[0].arn

  volume {
    name = "n8n-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.n8n[0].id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.n8n[0].id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "n8n"
      image     = var.n8n_image
      essential = true

      portMappings = [
        {
          containerPort = 5678
          protocol      = "tcp"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "n8n-data"
          containerPath = "/home/node/.n8n"
          readOnly      = false
        }
      ]

      environment = [
        { name = "N8N_HOST", value = var.n8n_domain },
        { name = "N8N_PORT", value = "5678" },
        { name = "N8N_PROTOCOL", value = "https" },
        { name = "WEBHOOK_URL", value = "https://${var.n8n_domain}" },
        { name = "N8N_EDITOR_BASE_URL", value = "https://${var.n8n_domain}" },

        # Database - PostgreSQL for execution history
        { name = "DB_TYPE", value = "postgresdb" },
        { name = "DB_POSTGRESDB_HOST", value = var.deploy_ecs ? aws_db_instance.n8n[0].address : "" },
        { name = "DB_POSTGRESDB_PORT", value = "5432" },
        { name = "DB_POSTGRESDB_DATABASE", value = "n8n" },
        { name = "DB_POSTGRESDB_USER", value = "n8n_admin" },
        { name = "DB_POSTGRESDB_SCHEMA", value = "n8n_executions" },

        # Incident Agent integration
        { name = "INCIDENT_TOPIC_ARN", value = var.incident_topic_arn },
        { name = "API_GATEWAY_URL", value = var.api_gateway_invoke_url },
        { name = "ANALYZER_INVOKE_URL", value = var.analyzer_invoke_url },
      ]

      secrets = [
        {
          name      = "DB_POSTGRESDB_PASSWORD"
          valueFrom = var.deploy_ecs ? lookup(var.secret_arns, "n8n_db_password", "") : ""
        },
        {
          name      = "N8N_ENCRYPTION_KEY"
          valueFrom = var.deploy_ecs ? lookup(var.secret_arns, "n8n_encryption_key", "") : ""
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.n8n[0].name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = var.tags
}

# -----------------------------------------------------------------------------
# UI Task Definition
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "ui" {
  count = var.deploy_ecs ? 1 : 0

  family                   = "${var.name_prefix}-ui"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.task_execution_role[0].arn
  task_role_arn            = aws_iam_role.task_role[0].arn

  container_definitions = jsonencode([
    {
      name      = "ui"
      image     = var.ui_image
      essential = true
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
      secrets = [
        {
          name      = "SLACK_WEBHOOK_SECRET_ARN"
          valueFrom = lookup(var.secret_arns, "slack_webhook", "")
        }
      ]
      environment = [
        {
          name  = "INCIDENT_API_URL"
          value = var.api_gateway_invoke_url
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ui[0].name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = var.tags
}

# -----------------------------------------------------------------------------
# ECS Services
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  name            = "${var.name_prefix}-n8n"
  cluster         = aws_ecs_cluster.this[0].id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.n8n[0].arn
  desired_count   = 1

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.n8n[0].arn
    container_name   = "n8n"
    container_port   = 5678
  }

  depends_on = [aws_lb_listener.n8n_https, aws_lb_listener.n8n_http]

  tags = var.tags
}

resource "aws_ecs_service" "ui" {
  count = var.deploy_ecs ? 1 : 0

  name            = "${var.name_prefix}-ui"
  cluster         = aws_ecs_cluster.this[0].id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.ui[0].arn
  desired_count   = 1

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# SNS Subscription - CloudWatch alarms → n8n webhook
# -----------------------------------------------------------------------------
resource "aws_sns_topic_subscription" "n8n_webhook" {
  count = var.deploy_ecs && var.n8n_domain != "" ? 1 : 0

  topic_arn = var.incident_topic_arn
  protocol  = "https"
  endpoint  = "https://${var.n8n_domain}/webhook/cloudwatch-alarm"

  delivery_policy = jsonencode({
    healthyRetryPolicy = {
      numRetries      = 3
      minDelayTarget  = 5
      maxDelayTarget  = 30
      backoffFunction = "exponential"
    }
  })
}
