terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.7"
    }
  }

  required_version = ">= 1.11.0"
}

provider "aws" {
  region = var.region
}

module "common" {
  source      = "../../modules/common"
  environment = local.environment
}

module "backend" {
  source                      = "../../modules/backend"
  region                      = var.region
  environment                 = local.environment
  app_name                    = "backend"
  domain                      = var.backend_domain
  ecs_task_execution_role_arn = module.common.ecs_task_execution_role_arn
  subnet_ids                  = module.common.public_subnet_ids
  security_group_id           = module.common.app_security_group_id
  vpc_id                      = module.common.vpc_id
  external_services = {
    CHAT_AI_MODEL_PROVIDER = "anthropic"
  }
  step_function_research_handler_arn       = module.step_function_research_handler.arn
  step_function_user_access_key_id_arn     = module.step_function_research_handler.step_function_user_access_key_id_secret_arn
  step_function_user_secret_access_key_arn = module.step_function_research_handler.step_function_user_secret_access_key_secret_arn
}

module "step_function_research_handler" {
  source                 = "../../modules/step_functions/research_handler"
  environment            = local.environment
  domain                 = var.backend_domain
  service_user_token_arn = module.backend.service_user_token_arn
}
