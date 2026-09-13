globals "shipmate" {
  env_order = {
    "dev-us" = ["dev-eu"]
  }

  # Dynamic backend: the layout derives `TF_VAR_env` from each environment's own
  # name and `TF_VAR_region` from its `region`, which is what the per-environment
  # variables carry today. Under `dry` every environment in the matrix needs an
  # entry with a non-empty region, or the run refuses at detect.
  layout = "dry"

  # The environment's own `region` inherits into `aws.region`, so the credentials
  # step gets the same region the stack does. `plan` and `apply` are separate
  # roles: the plan role is read-only and reachable from any branch, the apply
  # role is not.
  environments = {
    "dev-eu" = {
      region = "eu-west-1"
      aws = {
        plan  = { role = "arn:aws:iam::981781037707:role/shipmate-plan" }
        apply = { role = "arn:aws:iam::981781037707:role/shipmate-apply" }
      }
    }
    "dev-us" = {
      region = "us-east-1"
      aws = {
        plan  = { role = "arn:aws:iam::981781037707:role/shipmate-plan" }
        apply = { role = "arn:aws:iam::981781037707:role/shipmate-apply" }
      }
    }
    "sbx" = {
      region = "eu-west-1"
      aws = {
        plan  = { role = "arn:aws:iam::981781037707:role/sbx" }
        apply = { role = "arn:aws:iam::981781037707:role/sbx-apply" }
      }
    }
  }
}
