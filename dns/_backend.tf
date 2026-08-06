// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "local" {
    path = ".state/${var.env}/${var.region}/terraform.tfstate"
  }
}
