# Throwaway acceptance probe for consumer variables and secrets reaching a cell.
# Removed on the same pull request before it closes; never merged.
terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "= 2.3.5"
    }
  }
}

# Repository variable TF_VAR_PROBE_CONFIG, lowercased on export.
variable "probe_config" {
  type = string
}

# SHIPMATE_SECRETS entry, identical on both tiers because a TF_VAR_ is fingerprinted.
variable "probe_sentinel" {
  type = string
}

# PROBE_ENDPOINT (environment variable, identical on both tiers) and PROBE_TOKEN
# (SHIPMATE_SECRETS entry, different per tier), read by a provider's child process.
data "external" "plan_tier" {
  program = ["sh", "-c", <<-EOT
    printf '{"endpoint":"%s","token_sha":"%s"}' "$PROBE_ENDPOINT" "$(printf %s "$PROBE_TOKEN" | sha256sum | cut -c1-12)"
  EOT
  ]
}

resource "terraform_data" "probe" {
  input = {
    config    = var.probe_config
    sentinel  = var.probe_sentinel
    plan_tier = data.external.plan_tier.result
  }
  provisioner "local-exec" {
    command = "echo \"apply tier: endpoint=$PROBE_ENDPOINT token_sha=$(printf %s \"$PROBE_TOKEN\" | sha256sum | cut -c1-12)\""
  }
}
