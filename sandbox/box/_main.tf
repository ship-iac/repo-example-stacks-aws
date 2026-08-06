// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "random_pet" "this" {
  keepers = {
    app_version = var.app_version
  }
}
resource "terraform_data" "this" {
  input = random_pet.this.id
  triggers_replace = [
    var.app_version,
  ]
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
