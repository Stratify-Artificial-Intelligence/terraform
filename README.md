# Terraform

Veyra is an expert AI business mentor that helps you solve problems in your company, discover opportunities, and guides you step by step.

This repository contains Terraform code to manage Veyra's AWS infrastructure.


## Summary
- Two environments: `development` and `production` (under `environments/`).
- Re-usable modules live under `modules/` (common networking & IAM, backend service, EventBridge scheduler, Step Functions).
- Terraform provider: AWS (~> 6.7). Terraform required version >= 1.11.0.


## Repository structure
- environments/
  - development/
    - locals.tf            -> sets local.environment to "dev"
    - variables.tf         -> environment-specific variable defaults (region, backend_domain)
    - main.tf              -> wires modules for the development environment
    - terraform.tfstate*   -> (currently present in the repo; see State & Git notes)
  - production/
    - locals.tf            -> sets local.environment to "prod"
    - variables.tf         -> environment-specific variable defaults
    - main.tf              -> wires modules for the production environment
    - terraform.tfstate*   -> (currently present in the repo; see State & Git notes)

- modules/
  - common/                 -> VPC, subnets, security group, ECS task execution role and related IAM policies
  - backend/                -> ECR, ECS cluster/service/task, ALB, RDS (postgres), S3 bucket, secrets, autoscaling, and related wiring
  - eventbridge/business_research_scheduler/ -> IAM, Lambda placeholder, EventBridge Scheduler supporting resources
  - step_functions/research_handler/         -> Step Functions state machine, IAM roles and access keys


## Providers & versions
- Terraform configuration in each environment declares:
  - required_version = ">= 1.11.0"
  - required_providers { aws = { source = "hashicorp/aws" version = "~> 6.7" } }


## Environments (how to operate)
All environment Terraform configurations are self-contained under `environments/<env>/` and use local relative module sources (e.g. `../../modules/*`). The general workflow per environment is:
1. cd into the environment directory
  ```sh
  cd environments/development
  ```

2. Initialize (this will download providers and modules)
  ```sh
  terraform init
  ```

3. Optionally upgrade provider/plugins (if you need newer provider versions allowed by the constraints)
  ```sh
  terraform init -upgrade
  ```

4. Review a plan before applying
  ```sh
  terraform plan
  ```

5. Apply the plan
  ```sh
  terraform apply
  ```

6. Inspect outputs (after apply)
  ```sh
  terraform output
  terraform output -json
  ```

## Useful commands
- Format files
  ```sh
  terraform fmt -recursive
  ```

- Validate configuration
  ```sh
  terraform validate
  ```

- See the dependency graph
  ```sh
  terraform graph | dot -Tpng > graph.png
  ```

- Refresh state only
  ```sh
  terraform refresh
  ```

- Show resource(s) in state
  ```sh
  terraform state list
  ```

- Get detailed state for a resource
  ```sh
  terraform state show <resource_address>
  ```

- Import existing resources (useful when bringing resources under Terraform control)
  ```sh
  terraform import <address> <id>
  ```

- Destroy everything in an environment
  ```sh
  terraform destroy
  ```
