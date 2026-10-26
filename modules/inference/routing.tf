################################################################################
# InferencePool + Endpoint Picker (EPP)
#
# The llm-d router chart creates the InferencePool that selects the vLLM Pods
# by label, and the EPP Deployment the gateway consults for every request.
# The EPP scrapes each vLLM Pod's /metrics and picks the Pod with the shortest
# queue, the most free KV cache and a matching prefix cache.
################################################################################

resource "helm_release" "router" {
  name      = var.served_model_name
  namespace = var.namespace
  chart     = "oci://ghcr.io/llm-d/charts/llm-d-router-gateway"
  version   = var.router_chart_version

  set = [
    { name = "router.modelServers.matchLabels.app", value = local.labels.app },
    { name = "router.modelServers.matchLabels.model", value = local.labels.model },
    # Envoy Gateway + Agent Router need no provider-specific resources.
    { name = "provider.name", value = "none" },
    # The HTTPRoute is written below so that its timeouts are explicit.
    { name = "httpRoute.create", value = "false" },
    # Chart defaults request 8 CPUs and 8 GiB, which forces a large node.
    # One model and a handful of Pods need far less.
    { name = "router.epp.resources.requests.cpu", value = "500m" },
    { name = "router.epp.resources.requests.memory", value = "1Gi" },
    { name = "router.epp.resources.limits.memory", value = "2Gi" },
  ]

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

  depends_on = [helm_release.router]
}
