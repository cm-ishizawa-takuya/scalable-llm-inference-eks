################################################################################
# InferencePool + Endpoint Picker (EPP)
#
# The llm-d router chart creates the InferencePool that selects the vLLM Pods
# by label, and the EPP Deployment the gateway consults for every request.
# The EPP scrapes each vLLM Pod's /metrics and picks the Pod with the shortest
# queue, the most free KV cache and a matching prefix cache.
#
# Flow Control is enabled so that requests arriving while no vLLM Pod is
# ready (scaled to zero) wait in the EPP's queue instead of failing. The
# queue depth is also the signal KEDA uses to start the first replica.
################################################################################

locals {
  epp_plugins_config = yamlencode({
    apiVersion   = "llm-d.ai/v1"
    kind         = "EndpointPickerConfig"
    featureGates = ["flowControl"]
    plugins = [
      { type = "queue-scorer" },
      { type = "kv-cache-utilization-scorer" },
      { type = "prefix-cache-scorer" },
      { type = "round-robin-fairness-policy" },
      { type = "fcfs-ordering-policy" },
      {
        # Decides when the pool is saturated and dispatch should pause.
        type = "concurrency-detector"
        parameters = {
          maxConcurrency  = var.flow_control_max_concurrency
          concurrencyMode = "requests"
          headroom        = 0.0
        }
      },
    ]
    schedulingProfiles = [
      {
        name = "default"
        plugins = [
          { pluginRef = "queue-scorer", weight = 2 },
          { pluginRef = "kv-cache-utilization-scorer", weight = 2 },
          { pluginRef = "prefix-cache-scorer", weight = 3 },
        ]
      },
    ]
    flowControl = {
      maxBytes    = "1Gi"
      maxRequests = "1k"
      # A request queued at zero replicas must survive a full cold start.
      defaultRequestTTL  = var.request_timeout
      saturationDetector = { pluginRef = "concurrency-detector" }
      priorityBands = [
        {
          priority          = 0
          maxRequests       = "200"
          fairnessPolicyRef = "round-robin-fairness-policy"
          orderingPolicyRef = "fcfs-ordering-policy"
        },
      ]
    }
  })
}

resource "helm_release" "router" {
  name      = var.served_model_name
  namespace = var.namespace
  chart     = "oci://ghcr.io/llm-d/charts/llm-d-router-gateway"
  version   = var.router_chart_version

  values = [
    yamlencode({
      router = {
        modelServers = {
          matchLabels = local.labels
        }
        epp = {
          # Chart defaults request 8 CPUs and 8 GiB, which forces a large
          # node. One model and a handful of Pods need far less.
          resources = {
            requests = { cpu = "500m", memory = "1Gi" }
            limits   = { memory = "2Gi" }
          }
          # Picked up by Prometheus' kubernetes-pods scrape job.
          podAnnotations = {
            "prometheus.io/scrape" = "true"
            "prometheus.io/port"   = "9090"
            "prometheus.io/path"   = "/metrics"
          }
          pluginsConfigFile = "custom-plugins.yaml"
          pluginsCustomConfig = {
            "custom-plugins.yaml" = local.epp_plugins_config
          }
        }
        monitoring = {
          prometheus = {
            # Serve /metrics without a bearer token so that annotation-based
            # scraping works. Acceptable inside this private demo cluster.
            auth = { enabled = false }
          }
        }
      }
      # Envoy Gateway + Agent Router need no provider-specific resources.
      provider = { name = "none" }
      # The HTTPRoute is written below so that its timeouts are explicit.
      httpRoute = { create = false }
    }),
  ]

  depends_on = [kubernetes_manifest.namespace]
}

################################################################################
# GET /v1/models is answered by the gateway itself. Clients such as Open WebUI
# poll it constantly; if it reached the InferencePool it would wake vLLM from
# zero (and fail while nothing is ready). The answer only changes when the
# served model changes, so a fixed body is correct.
################################################################################

resource "kubernetes_manifest" "models_response" {
  manifest = {
    apiVersion = "gateway.envoyproxy.io/v1alpha1"
    kind       = "HTTPRouteFilter"
    metadata = {
      name      = "models-response"
      namespace = var.namespace
    }
    spec = {
      directResponse = {
        statusCode  = 200
        contentType = "application/json"
        body = {
          type = "Inline"
          inline = jsonencode({
            object = "list"
            data = [
              {
                id       = var.served_model_name
                object   = "model"
                created  = 0
                owned_by = "vllm"
              },
            ]
          })
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.namespace]
}

################################################################################
# HTTPRoute: everything on the Gateway goes to the InferencePool. Agent Router
# turns this backendRef into an ext_proc call to the EPP followed by a forward
# to the Pod the EPP chose.
################################################################################

resource "kubernetes_manifest" "httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = var.served_model_name
      namespace = var.namespace
    }
    spec = {
      parentRefs = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "Gateway"
          name      = var.gateway_name
          namespace = var.gateway_namespace
        },
      ]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "Exact"
                value = "/v1/models"
              }
            },
          ]
          filters = [
            {
              type = "ExtensionRef"
              extensionRef = {
                group = "gateway.envoyproxy.io"
                kind  = "HTTPRouteFilter"
                name  = "models-response"
              }
            },
          ]
        },
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            },
          ]
          backendRefs = [
            {
              group = "inference.networking.k8s.io"
              kind  = "InferencePool"
              name  = var.served_model_name
            },
          ]
          timeouts = {
            request        = var.request_timeout
            backendRequest = var.request_timeout
          }
        },
      ]
    }
  }

  depends_on = [helm_release.router, kubernetes_manifest.models_response]
}
