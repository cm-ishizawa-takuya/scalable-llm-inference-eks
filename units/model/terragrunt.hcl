include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "k8s" {
  path = find_in_parent_folders("k8s.hcl")
}

terraform {
  source = "../../modules/model"
}

inputs = {
  model_bucket_name = dependency.cluster.outputs.model_bucket_name
  model_bucket_arn  = dependency.cluster.outputs.model_bucket_arn
}
