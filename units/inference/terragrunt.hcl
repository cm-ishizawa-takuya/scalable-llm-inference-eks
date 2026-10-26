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

inputs = {
  # Pull the vLLM image through the ECR cache created by the cluster unit.
  vllm_image_repository = dependency.cluster.outputs.vllm_image_repository
  model_bucket_name     = dependency.cluster.outputs.model_bucket_name
  model_bucket_arn      = dependency.cluster.outputs.model_bucket_arn
}
