include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/nodepool"
}

# Outputs of the cluster unit feed the kubernetes provider below.
dependency "cluster" {
  config_path = "../cluster"
}

generate "kubernetes_provider" {
  path      = "kubernetes_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-PROVIDER
    provider "kubernetes" {
      host                   = "${dependency.cluster.outputs.cluster_endpoint}"
      cluster_ca_certificate = base64decode("${dependency.cluster.outputs.cluster_certificate_authority_data}")

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "${dependency.cluster.outputs.cluster_name}", "--region", "${dependency.cluster.outputs.region}"]
      }
    }
  PROVIDER
}
