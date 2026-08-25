globals {
  version        = "12"
  workload       = "platform"
  state_role_arn = "arn:aws:iam::981781037707:role/shipmate-state"
}

# Two blocks, mutually exclusive conditions: Terramate 0.17.1 has no `tm_unset()`,
# and bare `unset` emits `assume_role = unset`, surviving fmt and validate to die at init.
generate_hcl "_backend.tf" {
  condition = global.state_role_arn != ""
  content {
    terraform {
      backend "s3" {
        bucket       = "repo-examples-shipmate-state"
        key          = "repo-example-stacks-aws/${var.env}/${var.region}${terramate.stack.path.absolute}/terraform.tfstate"
        region       = "eu-north-1"
        use_lockfile = true
        encrypt      = true
        profile      = var.use_profile ? "${global.workload}-${var.env}" : null
        assume_role = {
          role_arn = global.state_role_arn
        }
      }
    }
  }
}

generate_hcl "_backend.tf" {
  condition = global.state_role_arn == ""
  content {
    terraform {
      backend "s3" {
        bucket       = "repo-examples-shipmate-state"
        key          = "repo-example-stacks-aws/${var.env}/${var.region}${terramate.stack.path.absolute}/terraform.tfstate"
        region       = "eu-north-1"
        use_lockfile = true
        encrypt      = true
        profile      = var.use_profile ? "${global.workload}-${var.env}" : null
      }
    }
  }
}

generate_hcl "_providers.tf" {
  content {
    terraform {
      required_providers {
        random = {
          source  = "hashicorp/random"
          version = "~> 3.0"
        }
        aws = {
          source = "hashicorp/aws"
          # Exact, not `~> 6.0`: .terraform.lock.hcl is gitignored, so every
          # init re-resolves; a release inside a plan/apply window would make
          # tofu refuse the saved plan.
          version = "= 6.58.0"
        }
      }
    }
    provider "aws" {
      region  = var.region
      profile = var.use_profile ? "${global.workload}-${var.env}" : null
      default_tags {
        tags = {
          shipmate-env   = var.env
          shipmate-stack = terramate.stack.path.absolute
        }
      }
    }
  }
}

generate_hcl "_variables.tf" {
  content {
    variable "env" { type = string }
    variable "region" { type = string }
    variable "app_version" {
      type    = string
      default = global.version
    }
    variable "fail_precondition" {
      type    = bool
      default = false
    }
    # Defaults false: CI runs on ambient OIDC credentials and the apply path
    # has no way to set it.
    variable "use_profile" {
      type    = bool
      default = false
    }
  }
}

generate_hcl "_main.tf" {
  content {
    resource "random_pet" "this" {
      keepers = {
        app_version = var.app_version
      }
    }
    resource "terraform_data" "this" {
      triggers_replace = [var.app_version]
      input            = random_pet.this.id
      lifecycle {
        precondition {
          condition     = !var.fail_precondition
          error_message = "fail_precondition fixture is enabled"
        }
      }
    }
    resource "aws_ssm_parameter" "this" {
      name  = "/shipmate/repo-example-stacks-aws/${var.env}${terramate.stack.path.absolute}"
      type  = "String"
      value = random_pet.this.id
    }
    output "name" {
      value = random_pet.this.id
    }
    output "parameter_name" {
      value = aws_ssm_parameter.this.name
    }
  }
}
