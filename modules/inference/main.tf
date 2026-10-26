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

################################################################################
# Pod Identity: vLLM may read the model bucket
################################################################################

resource "aws_iam_role" "vllm" {
  name = "${var.cluster_name}-vllm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy" "vllm" {
  name = "model-bucket-read"
  role = aws_iam_role.vllm.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = var.model_bucket_arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${var.model_bucket_arn}/${var.model_s3_prefix}/*"
      },
    ]
  })
}

resource "kubernetes_manifest" "vllm_sa" {
  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "vllm"
      namespace = var.namespace
    }
  }

  depends_on = [kubernetes_manifest.namespace]
}

resource "aws_eks_pod_identity_association" "vllm" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "vllm"
  role_arn        = aws_iam_role.vllm.arn
}

################################################################################
# vLLM
################################################################################

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
      # No replicas here: KEDA owns the count (0 when idle). Kubernetes
      # defaults a new Deployment to 1 until KEDA takes over.
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
          # Picked up by Prometheus' kubernetes-pods scrape job.
          annotations = {
            "prometheus.io/scrape" = "true"
            "prometheus.io/port"   = "8000"
            "prometheus.io/path"   = "/metrics"
          }
        }
        spec = {
          # Service links would inject VLLM_PORT=tcp://... for the "vllm"
          # Service, which collides with vLLM's own VLLM_PORT setting and
          # crashes the engine on startup.
          enableServiceLinks = false
          serviceAccountName = "vllm"
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
              image = "${var.vllm_image_repository}:${var.vllm_image_tag}"
              args = [
                # Weights stream from S3 through the gateway endpoint; the
                # Run:ai Model Streamer reads safetensors directly into GPU memory.
                "--model", "s3://${var.model_bucket_name}/${var.model_s3_prefix}",
                "--load-format", "runai_streamer",
                "--served-model-name", var.served_model_name,
                "--dtype", var.dtype,
                "--max-model-len", tostring(var.max_model_len),
                "--gpu-memory-utilization", tostring(var.gpu_memory_utilization),
                # Chat UIs send tool_choice=auto; vLLM rejects it unless tool
                # calling is enabled. hermes is the parser for Qwen3.
                "--enable-auto-tool-choice",
                "--tool-call-parser", var.tool_call_parser,
                "--port", "8000",
              ]
              env = [
                {
                  name  = "HF_HOME"
                  value = "/cache/huggingface"
                },
                {
                  # Everything comes from S3. Fail loudly if anything still
                  # tries to reach Hugging Face through the NAT gateway.
                  name  = "HF_HUB_OFFLINE"
                  value = "1"
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

  # KEDA's HPA changes the replica count at runtime; do not fight it.
  computed_fields = ["metadata.annotations", "metadata.labels", "spec.replicas"]
  field_manager {
    force_conflicts = true
  }

  depends_on = [
    kubernetes_manifest.namespace,
    kubernetes_manifest.vllm_sa,
    aws_eks_pod_identity_association.vllm,
  ]
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
