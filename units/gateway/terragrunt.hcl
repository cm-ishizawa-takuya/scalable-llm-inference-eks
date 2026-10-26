include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "k8s" {
  path = find_in_parent_folders("k8s.hcl")
}

terraform {
  source = "../../modules/gateway"
}

# The CRDs and controllers these resources need come from the platform unit.
dependencies {
  paths = ["../platform"]
}
