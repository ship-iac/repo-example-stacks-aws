// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "s3" {
    bucket       = "repo-examples-shipmate-state"
    encrypt      = true
    key          = "repo-example-stacks-aws/${var.env}/${var.region}/sandbox/box/terraform.tfstate"
    profile      = var.use_profile ? "sandbox-${var.env}" : null
    region       = "eu-north-1"
    use_lockfile = true
  }
}
