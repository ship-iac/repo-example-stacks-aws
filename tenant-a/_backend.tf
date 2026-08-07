// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "s3" {
    assume_role = {
      role_arn = "arn:aws:iam::981781037707:role/shipmate-state"
    }
    bucket       = "repo-examples-shipmate-state"
    encrypt      = true
    key          = "repo-example-stacks-aws/${var.env}/${var.region}/tenant-a/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
  }
}
