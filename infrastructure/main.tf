module "dynamodb" {
  source = "./modules/dynamodb"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "secrets_manager" {
  source = "./modules/secrets_manager"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "sns" {
  source = "./modules/sns"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "lambda" {
  source = "./modules/lambda"

  name_prefix        = local.name_prefix
  environment        = local.environment
  tags               = local.common_tags
  create_functions   = var.create_lambda_functions
  package_paths      = var.lambda_package_paths
  table_names        = module.dynamodb.table_names
  secret_arns        = module.secrets_manager.secret_arns
  incident_topic_arn = module.sns.topic_arn
}

module "api_gateway" {
  source = "./modules/api_gateway"

  name_prefix     = local.name_prefix
  tags            = local.common_tags
  normalizer_arn  = module.lambda.invoke_arns.normalizer
  config_api_arn  = module.lambda.invoke_arns.config_api
  normalizer_name = module.lambda.function_names.normalizer
  config_api_name = module.lambda.function_names.config_api
}

module "ecs" {
  source = "./modules/ecs"

  name_prefix            = local.name_prefix
  tags                   = local.common_tags
  deploy_ecs             = var.deploy_ecs
  vpc_id                 = var.vpc_id
  subnet_ids             = var.private_subnet_ids
  security_group_ids     = var.ecs_security_group_ids
  ui_image               = var.ui_image
  n8n_image              = var.n8n_image
  secret_arns            = module.secrets_manager.secret_arns
  api_gateway_invoke_url = module.api_gateway.invoke_url
  incident_topic_arn     = module.sns.topic_arn
}
