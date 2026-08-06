stack {
  name        = "app"
  description = "app"
  tags        = ["env/dev-eu", "env/dev-us"]
  after       = ["/stacks/auth", "/stacks/workers"]
  id          = "61279720-23b2-4691-a868-ebb24b0972a9"
}
