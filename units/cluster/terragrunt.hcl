include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/cluster"
}

inputs = {
  kubernetes_version = "1.36"
}
