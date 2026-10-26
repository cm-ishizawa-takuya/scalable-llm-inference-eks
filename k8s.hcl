# Shared by every unit that talks to the Kubernetes API. Units include it with
# `include "k8s" { path = find_in_parent_folders("k8s.hcl") }` in addition to
# root.hcl. The cluster unit's outputs feed the kubernetes provider.

dependency "cluster" {
  config_path = "${dirname(find_in_parent_folders("root.hcl"))}/units/cluster"
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
