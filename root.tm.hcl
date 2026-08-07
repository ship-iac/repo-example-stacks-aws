globals {
  version = "6"
}

generate_hcl "_backend.tf" {
  content {
    terraform {
      backend "s3" {
        bucket       = "repo-examples-shipmate-state"
        key          = "repo-example-stacks-aws/${var.env}/${var.region}${terramate.stack.path.absolute}/terraform.tfstate"
        region       = "eu-north-1"
        use_lockfile = true
        encrypt      = true
        assume_role = {
          role_arn = "arn:aws:iam::981781037707:role/shipmate-state"
        }
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
      region = var.region
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

script "plan" {
  description = "plan this stack"
  job {
    commands = [
      ["tofu", "init", "-input=false"],
      ["tofu", "plan", "-input=false", "-lock=false", "-out=stack.otplan"],
    ]
  }
}

script "apply" {
  description = "apply this stack"
  job {
    commands = [
      ["tofu", "init", "-input=false"],
      ["tofu", "apply", "-input=false", "-auto-approve", "stack.otplan"],
    ]
  }
}
