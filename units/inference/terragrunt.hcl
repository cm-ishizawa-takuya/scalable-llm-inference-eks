include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "k8s" {
  path = find_in_parent_folders("k8s.hcl")
}

terraform {
  source = "../../modules/inference"
}

# No outputs are needed from the GPU NodePool, but vLLM Pods cannot start
# without it, so `run --all` must apply it first.
dependencies {
  paths = ["../nodepool"]
}
