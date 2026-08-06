# Terramate script SUBTREE OVERRIDE — the `auth` stack runs `tofu validate` as
# an extra pre-plan / pre-apply gate. A deeper `script` definition replaces the
# root's (stacks/root.tm.hcl) for stacks under this directory. This is
# shipmate's substitute for per-pipeline / per-stack workflow config: customize
# one stack's pipeline without touching workflow YAML or the other stacks.
script "plan" {
  description = "plan (auth: +validate gate)"
  job {
    commands = [
      ["tofu", "init", "-input=false"],
      ["tofu", "validate"],
      ["tofu", "plan", "-input=false", "-lock=false", "-out=stack.otplan"],
    ]
  }
}
script "apply" {
  description = "apply (auth: +validate gate)"
  job {
    commands = [
      ["tofu", "init", "-input=false"],
      ["tofu", "validate"],
      ["tofu", "apply", "-input=false", "-lock=false", "-auto-approve", "stack.otplan"],
    ]
  }
}
