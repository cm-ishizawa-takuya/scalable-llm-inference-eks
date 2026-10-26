# GPU NodePool for EKS Auto Mode. It reuses the built-in `default` NodeClass,
# so subnets, security groups and the node IAM role come from the cluster.
resource "kubernetes_manifest" "gpu_nodepool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "gpu"
    }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "eks.amazonaws.com"
            kind  = "NodeClass"
            name  = "default"
          }
          requirements = [
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = var.gpu_instance_types
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = var.gpu_capacity_types
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
          ]
          # Keep CPU-only Pods off the GPU nodes. GPU Pods add a toleration.
          taints = [
            {
              key    = "nvidia.com/gpu"
              value  = "true"
              effect = "NoSchedule"
            },
          ]
        }
      }
      disruption = {
        # Only remove nodes once nothing runs on them. Never evict a running
        # inference Pod to repack the cluster.
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = var.consolidate_after
      }
      limits = {
        "nvidia.com/gpu" = tostring(var.gpu_limit)
      }
    }
  }
}
