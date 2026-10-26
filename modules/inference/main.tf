locals {
  labels = {
    app   = "vllm"
    model = var.served_model_name
  }
}

resource "kubernetes_manifest" "namespace" {
  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = var.namespace
    }
  }
}

resource "kubernetes_manifest" "vllm" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "vllm"
      namespace = var.namespace
      labels    = local.labels
    }
    spec = {
      replicas = var.replicas
      selector = {
        matchLabels = local.labels
      }
      # One GPU per Pod and a small GPU budget: replace in place instead of
      # starting a second node for every rollout.
      strategy = {
        type = "Recreate"
      }
      template = {
        metadata = {
          labels = local.labels
        }
        spec = {
          # Service links would inject VLLM_PORT=tcp://... for the "vllm"
          # Service, which collides with vLLM's own VLLM_PORT setting and
          # crashes the engine on startup.
          enableServiceLinks = false
          tolerations = [
            {
              key      = "nvidia.com/gpu"
              operator = "Exists"
              effect   = "NoSchedule"
            },
          ]
          containers = [
            {
              name  = "vllm"
              image = var.vllm_image
              args = [
                "--model", var.model_id,
                "--served-model-name", var.served_model_name,
                "--dtype", var.dtype,
                "--max-model-len", tostring(var.max_model_len),
                "--gpu-memory-utilization", tostring(var.gpu_memory_utilization),
                "--port", "8000",
              ]
              env = [
                {
                  name  = "HF_HOME"
                  value = "/cache/huggingface"
                },
              ]
              ports = [
                {
                  name          = "http"
                  containerPort = 8000
                },
              ]
              resources = {
                requests = {
                  cpu              = "3"
                  memory           = "12Gi"
                  "nvidia.com/gpu" = "1"
                }
                limits = {
                  "nvidia.com/gpu" = "1"
                }
              }
              # Image pull, weight download and model load take minutes.
              # Give the startup probe up to 15 minutes before restarting.
              startupProbe = {
                httpGet = {
                  path = "/health"
                  port = "http"
                }
                periodSeconds    = 10
                failureThreshold = 90
              }
              readinessProbe = {
                httpGet = {
                  path = "/health"
                  port = "http"
                }
                periodSeconds = 10
              }
              livenessProbe = {
                httpGet = {
                  path = "/health"
                  port = "http"
                }
                periodSeconds    = 30
                failureThreshold = 3
              }
              volumeMounts = [
                {
                  name      = "model-cache"
                  mountPath = "/cache"
                },
                {
                  name      = "shm"
                  mountPath = "/dev/shm"
                },
              ]
            },
          ]
          volumes = [
            {
              # Lives on the node's local NVMe. Lost when the node goes away,
              # which is the cold start this sample measures.
              name = "model-cache"
              emptyDir = {
                sizeLimit = var.model_cache_size
              }
            },
            {
              name = "shm"
              emptyDir = {
                medium    = "Memory"
                sizeLimit = "2Gi"
              }
            },
          ]
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.namespace]
}

resource "kubernetes_manifest" "vllm_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "vllm"
      namespace = var.namespace
      labels    = local.labels
    }
    spec = {
      selector = local.labels
      ports = [
        {
          name       = "http"
          port       = 8000
          targetPort = "http"
        },
      ]
    }
  }

  depends_on = [kubernetes_manifest.namespace]
}
