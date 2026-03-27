data "aws_region" "current" {}

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

resource "aws_ecs_cluster" "this" {
  count = var.deploy_ecs ? 1 : 0

  name = "${var.name_prefix}-cluster"
  tags = var.tags
}

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
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  count = var.deploy_ecs ? 1 : 0

  name   = "${var.name_prefix}-ecs-task-policy"
  role   = aws_iam_role.task_role[0].id
  policy = data.aws_iam_policy_document.ecs_task_policy.json
}

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

resource "aws_ecs_task_definition" "n8n" {
  count = var.deploy_ecs ? 1 : 0

  family                   = "${var.name_prefix}-n8n"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.task_execution_role[0].arn
  task_role_arn            = aws_iam_role.task_role[0].arn

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
      environment = [
        {
          name  = "INCIDENT_TOPIC_ARN"
          value = var.incident_topic_arn
        },
        {
          name  = "API_GATEWAY_URL"
          value = var.api_gateway_invoke_url
        }
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
