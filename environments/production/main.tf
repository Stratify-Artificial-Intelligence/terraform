terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
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
    CHAT_AI_MODEL_PROVIDER = "openai"
  }
}
