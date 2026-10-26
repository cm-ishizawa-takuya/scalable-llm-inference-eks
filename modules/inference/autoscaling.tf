################################################################################
# KEDA ScaledObject: scale vLLM on the number of requests in flight, as seen
# by the Endpoint Picker. KEDA creates and drives an HPA for the Deployment.
#
# Why the EPP metric and not vLLM's own queue length: with continuous batching
# a small model on one GPU runs many requests at once without ever queueing,
# while latency per request already degrades. Concurrency per replica is the
# signal users feel. The EPP is also always running, so the series exists even
# when vLLM is at zero replicas.
#
# Two triggers:
#   - in-flight requests per replica drive 1 -> N;
#   - the Flow Control queue depth drives 0 -> 1: at zero replicas every
#     request waits in the EPP queue, the queue metric goes above zero and
#     KEDA activates the Deployment.
# After cooldownPeriod with both triggers at zero, KEDA scales back to zero.
################################################################################

resource "kubernetes_manifest" "vllm_scaledobject" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata = {
      name      = "vllm"
      namespace = var.namespace
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind       = "Deployment"
        name       = "vllm"
      }
      pollingInterval = 15
      cooldownPeriod  = 300
      minReplicaCount = var.min_replicas
      maxReplicaCount = var.max_replicas
      advanced = {
        horizontalPodAutoscalerConfig = {
          behavior = {
            # A new replica takes minutes to become Ready. Without a window
            # the HPA keeps adding replicas while the first one is still
            # loading the model.
            scaleUp = {
              stabilizationWindowSeconds = var.scale_up_stabilization_seconds
            }
            scaleDown = {
              stabilizationWindowSeconds = 300
            }
          }
        }
      }
      triggers = [
        {
          type       = "prometheus"
          metricType = "AverageValue"
          metadata = {
            serverAddress = var.prometheus_url
            query         = "sum(llm_d_epp_request_running{namespace=\"${var.namespace}\"})"
            # In-flight requests per replica before another replica is added.
            threshold = tostring(var.running_requests_per_replica)
          }
        },
        {
          type       = "prometheus"
          metricType = "AverageValue"
          metadata = {
            serverAddress = var.prometheus_url
            query         = "sum(llm_d_epp_flow_control_queue_size{namespace=\"${var.namespace}\"})"
            # Any queued request means capacity is missing.
            threshold = "1"
          }
        },
      ]
    }
  }

  depends_on = [kubernetes_manifest.vllm]
}
