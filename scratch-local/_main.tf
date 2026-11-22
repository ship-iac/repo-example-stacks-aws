// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "random_pet" "this" {
  keepers = {
    app_version = var.app_version
  }
}
output "name" {
  value = random_pet.this.id
}
