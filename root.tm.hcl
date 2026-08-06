globals {
  version = "6"
}

generate_hcl "_backend.tf" {
  content {
    terraform {
      backend "local" {
        path = ".state/${var.env}/${var.region}/terraform.tfstate"
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
    output "name" {
      value = random_pet.this.id
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
      ["tofu", "apply", "-input=false", "-lock=false", "-auto-approve", "stack.otplan"],
    ]
  }
}
