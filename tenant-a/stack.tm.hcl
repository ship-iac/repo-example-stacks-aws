stack {
  name        = "tenant-a"
  description = "tenant-a (prd2-1e)"
  tags        = ["env/dev-eu", "env/dev-us"]
  after       = ["/stacks/app"]
  id          = "dbf84603-8f9d-4c8a-97da-33e32d4a4ecb"
}
