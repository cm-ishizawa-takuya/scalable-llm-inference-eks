include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "k8s" {
  path = find_in_parent_folders("k8s.hcl")
}

terraform {
  source = "../../modules/inference"
}

# No outputs are needed from these units, but vLLM cannot start before the
# GPU NodePool exists and the weights are in S3, so `run --all` applies them
# first.
dependencies {
  paths = ["../nodepool", "../model"]
}

# The HTTPRoute attaches to the Gateway created by the gateway unit.
dependency "gateway" {
  config_path = "../gateway"
}

generate "helm_provider" {
  path      = "helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-PROVIDER
    provider "helm" {
      kubernetes = {
        host                   = "${dependency.cluster.outputs.cluster_endpoint}"
        cluster_ca_certificate = base64decode("${dependency.cluster.outputs.cluster_certificate_authority_data}")

        exec = {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.cluster.outputs.cluster_name}", "--region", "${dependency.cluster.outputs.region}"]
        }
      }
    }
  PROVIDER
}

inputs = {
  # Start with one replica; autoscaling takes over in a later unit.
  replicas = 1

  # Pull the vLLM image through the ECR cache created by the cluster unit.
  vllm_image_repository = dependency.cluster.outputs.vllm_image_repository
  model_bucket_name     = dependency.cluster.outputs.model_bucket_name
  model_bucket_arn      = dependency.cluster.outputs.model_bucket_arn
  gateway_name          = dependency.gateway.outputs.gateway_name
  gateway_namespace     = dependency.gateway.outputs.gateway_namespace
}
