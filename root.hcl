# Shared configuration for every unit. Units include this file with
# `include "root" { path = find_in_parent_folders("root.hcl") }`.

locals {
  # The region comes from the environment so that the repository itself does
  # not assume one. Terragrunt fails fast when AWS_REGION is unset.
  region       = get_env("AWS_REGION")
  account_id   = get_aws_account_id()
  cluster_name = "scalable-llm-inference"
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket       = "${local.cluster_name}-tfstate-${local.account_id}-${local.region}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.region
    encrypt      = true
    use_lockfile = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-PROVIDER
    provider "aws" {
      region = "${local.region}"

      default_tags {
        tags = {
          Project = "${local.cluster_name}"
        }
      }
    }
  PROVIDER
}

inputs = {
  region       = local.region
  cluster_name = local.cluster_name

  # The model is referenced by two units: `model` uploads it to S3 and
  # `inference` serves it from there, so both read the same values.
  model_id        = "Qwen/Qwen3-4B-Instruct-2507"
  model_s3_prefix = "qwen3-4b-instruct-2507"
}
