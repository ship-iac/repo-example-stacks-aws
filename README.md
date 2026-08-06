# repo-example-stacks-aws

A minimal [Terramate](https://terramate.io/) + [OpenTofu](https://opentofu.org/)
monorepo that exercises the **shipmate** GitHub Actions against a realistic
multi-stack, multi-environment dependency graph — code generation, stack
discovery by tag, dependency-graph (`after`) ordering, and three common CI
failure modes — **without touching any real cloud**.

- Every stack manages only `random_pet` / `terraform_data` null resources.
- State is **local** (`.state/<env>/<region>/terraform.tfstate` per stack).
- **Zero cloud credentials** are required to run any of it by hand; the
  workflows assume a role via OIDC, which the local-backend stacks never use.

This is the **DRY / dynamic-backend** layout: one stack directory is applied
N times, once per environment, distinguished only by the `TF_VAR_env` /
`TF_VAR_region` injected by each GitHub Environment. (Sibling repos
`repo-example-folders` and `repo-example-workspaces` prove the same engine
against the folder-per-env and workspace-per-env layouts.)

## What this repo tests

The engine ships three workflows (pinned by commit SHA in
`.github/workflows/`):

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `plan.yml` | pull request | fan out one plan per stack × env, publish plan artifacts, create a pending apply check per cell, gate on `shipmate / gate` |
| `deploy.yml` | push to `main` | apply the reviewed plans in **waves** (topological levels of the `after` DAG) |
| `drift.yml` | schedule | plan every stack × env and open/update/close a drift issue |

The stacks, tags, and DAG below are the fixture those workflows run against.

## Toolchain

- Terramate 0.17.1
- OpenTofu 1.12.4

## Quickstart

```bash
git clone <this-repo-url> repo-example-stacks-aws
cd repo-example-stacks-aws

# Regenerate per-stack backend/provider/variables/main files from
# root.tm.hcl. Committed generated files are up to date, so this
# prints "Nothing to do, generated code is up to date".
terramate generate

# List every stack tagged for the dev-eu environment.
terramate list --tags env/dev-eu

# Print the full cross-stack dependency graph (Graphviz DOT).
terramate experimental run-graph

# Drive one stack: dns is dev-us / us-east-1.
cd dns
export TF_VAR_env=dev-us
export TF_VAR_region=us-east-1
tofu init -input=false
tofu plan -input=false
```

Expect `tofu plan` to show 2 resources to add (`random_pet.this`,
`terraform_data.this`) on a stack that has never been applied.

> **Windows (PowerShell):** set vars with `$env:TF_VAR_env = "dev-us"` instead
> of `export`.

## Repository layout

```
repo-example-stacks-aws/
├── terramate.tm.hcl      # enables the "scripts" experiment
├── env-order.tm.hcl      # cross-environment apply order
├── tools/
│   └── mutate-state.ps1  # drift fixture helper
├── root.tm.hcl           # shared globals + generate_hcl blocks + scripts,
│                         # inherited by every stack beside it
├── dns/                  # env/dev-us
├── platform/             # env/dev-eu, after dns
├── auth/                 # env/dev-eu, after platform
├── workers/              # env/dev-eu, after platform
├── app/                  # env/dev-eu + env/dev-us, after auth & workers
├── tenant-a/             # env/dev-eu + env/dev-us, after app
├── tenant-b/             # env/dev-eu + env/dev-us, after app
└── sandbox/box/          # env/sbx, standalone (no dependents/dependencies)
```

Every stack sits at the repo root — there is no `stacks/` wrapper directory.

Each stack directory holds a `stack.tm.hcl` (name, tags, `after` dependencies,
stable UUID) plus four Terramate-generated files you should never hand-edit:
`_backend.tf`, `_providers.tf`, `_variables.tf`, `_main.tf`. They all begin
with `// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT` and come from the
`generate_hcl` blocks in `root.tm.hcl`. To change a stack's contents,
edit `root.tm.hcl` and rerun `terramate generate` — never edit the generated
`.tf` files (Terramate will refuse to regenerate over manual edits).

## Tag convention: `env/<name>`

Stacks carry a slash-separated `env/<name>` tag, never a colon (`env/dev-eu`,
not `env:dev-eu` — Terramate forbids `:` in tags). A stack may carry more than
one `env/*` tag when it's instantiated in more than one environment (`app`,
`tenant-a`, `tenant-b` all carry both `env/dev-eu` and `env/dev-us`). Select
the stacks for one environment with `terramate list --tags env/<name>`.

`sandbox/box` is tagged `env/sbx` — a standalone scratch stack excluded from
both `env/dev-eu` and `env/dev-us`, with no `after` and nothing depending on it.

## The dependency graph

`after = [...]` in each `stack.tm.hcl` wires up a single, environment-agnostic
5-level DAG:

```
dns (dev-us)
 └─▶ platform (dev-eu)
      ├─▶ auth (dev-eu)
      │    └─▶ app (dev-eu, dev-us)
      │         ├─▶ tenant-a (dev-eu, dev-us)
      │         └─▶ tenant-b (dev-eu, dev-us)
      └─▶ workers (dev-eu)
           └─▶ app  (same node as above)

sandbox/box (sbx)   — disconnected, no edges
```

The graph is **not** duplicated per environment. `dns` runs only under
`dev-us`/`us-east-1`; `platform`/`auth`/`workers` only under `dev-eu`. `app`,
`tenant-a`, `tenant-b` straddle both — the *same* directory applied twice, once
per environment, chosen purely by the `TF_VAR_env`/`TF_VAR_region` exported
before `tofu`. Ordering (`after`) is stack-to-stack, not per-environment. This
DAG is what `deploy.yml` walks in waves.

Confirm it:

```bash
terramate experimental run-graph
```

prints DOT with edges `dns->platform`, `platform->auth`, `platform->workers`,
`auth->app`, `workers->app`, `app->tenant-a`, `app->tenant-b`, and `box` with
no edges.

## Environment / region model

Nothing in a stack's generated code hardcodes an environment or region.
`root.tm.hcl` generates:

- `_variables.tf` declaring `var.env`, `var.region` (both required, no
  default), plus `var.app_version` and `var.fail_precondition`.
- `_backend.tf` pointing the local backend at
  `.state/${var.env}/${var.region}/terraform.tfstate` — so state never collides
  across environments even though it's the same directory.

In CI the values come from each GitHub Environment (`TF_VAR_env`,
`TF_VAR_region`). By hand you export them:

| Stack        | Example invocation |
|--------------|--------------------|
| dns          | `TF_VAR_env=dev-us TF_VAR_region=us-east-1` |
| platform     | `TF_VAR_env=dev-eu TF_VAR_region=eu-west-1` |
| auth/workers | `TF_VAR_env=dev-eu TF_VAR_region=eu-west-1` |
| app/tenant-* | `dev-eu`/`eu-west-1` **or** `dev-us`/`us-east-1` (run once per env) |

## Driving a stack by hand

`cd` into a stack, set the two required vars, `tofu init`, `tofu plan` (add
`tofu apply -auto-approve` to actually create the null resources). Example,
`platform` (dev-eu / eu-west-1):

```bash
cd platform
export TF_VAR_env=dev-eu
export TF_VAR_region=eu-west-1
tofu init -input=false
tofu plan -input=false
```

Terramate also ships two convenience scripts (defined in `root.tm.hcl`,
needing the `scripts` experiment already enabled in `terramate.tm.hcl`), run
from inside a stack directory with the vars still exported:

```bash
terramate script run plan    # tofu init && tofu plan -out=stack.otplan
terramate script run apply   # tofu init && tofu apply -auto-approve stack.otplan
```

## Failure fixtures

Three fixtures simulate the CI failures this repo exists to exercise. Each is
independent — run them in any order, against any stack (examples use `dns`,
`TF_VAR_env=dev-us`, `TF_VAR_region=us-east-1`).

### 1. Precondition failure

```bash
export TF_VAR_fail_precondition=true
tofu plan -input=false
```

Expected: plan fails with `Error: Resource precondition failed … fail_precondition
fixture is enabled`, exit code 1. Unset with `unset TF_VAR_fail_precondition`.

### 2. Drift

Requires the stack applied at least once (`tofu apply -input=false
-auto-approve`). `tools/mutate-state.ps1` deletes the `random_pet` resource
straight out of local state, bypassing OpenTofu, so the next plan reports real
drift. It's a PowerShell helper (drift is normally injected out-of-band); on
Linux run it via `pwsh`:

```bash
pwsh tools/mutate-state.ps1 -StateFile ".state/dev-us/us-east-1/terraform.tfstate"
tofu plan -input=false -detailed-exitcode
```

Expected: exit code **2** (changes present) — `random_pet.this` re-created,
`terraform_data.this` updated in place. (`-detailed-exitcode`: 0 = no changes,
1 = error, 2 = changes.)

### 3. Stale plan

```bash
tofu plan -input=false -out stack.otplan
export TF_VAR_app_version=99      # simulate a concurrent apply with a new input
tofu apply -input=false -auto-approve
unset TF_VAR_app_version
tofu apply stack.otplan
```

Expected: the final `tofu apply stack.otplan` fails with `Error: Saved plan is
stale … the state was changed by another operation after the plan was created`,
exit code 1. This is the exact-plan / fail-safe behavior shipmate's `apply-cell`
relies on.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
