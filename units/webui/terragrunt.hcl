include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "k8s" {
  path = find_in_parent_folders("k8s.hcl")
}

terraform {
  source = "../../modules/webui"
}

dependency "gateway" {
  config_path = "../gateway"
}

# Open WebUI is only useful once the model route exists.
dependencies {
  paths = ["../inference"]
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
  openai_api_base_url = "http://${dependency.gateway.outputs.gateway_name}.${dependency.gateway.outputs.gateway_namespace}.svc.cluster.local/v1"
}
